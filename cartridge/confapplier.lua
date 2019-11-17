#!/usr/bin/env tarantool

--- Clusterwide configuration management primitives.
-- @module cartridge.confapplier

local log = require('log')
local fio = require('fio')
local yaml = require('yaml').new()
local fiber = require('fiber')
local errors = require('errors')
local checks = require('checks')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.confapplier')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local e_yaml = errors.new_class('Parsing yaml failed')
local e_failover = errors.new_class('Failover failed')
local e_config_load = errors.new_class('Loading configuration failed')
local e_config_fetch = errors.new_class('Fetching configuration failed')
local e_config_apply = errors.new_class('Applying configuration failed')
local e_config_validate = errors.new_class('Invalid config')
local e_register_role = errors.new_class('Can not register role')

vars:new('conf')
vars:new('workdir')
vars:new('locks', {})
vars:new('known_roles', {
    -- [i] = mod,
    -- [role_name] = mod,
})
vars:new('roles_dependencies', {
    -- [role_name] = {role_name_1, role_name_2}
})
vars:new('roles_dependants', {
    -- [role_name] = {role_name_1, role_name_2}
})
vars:new('applier_fiber', nil)
vars:new('applier_channel', nil)
vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

local function set_workdir(workdir)
    checks('string')
    vars.workdir = workdir
end

local function register_role(module_name)
    checks('string')
    local function e(...)
        vars.known_roles = {}
        vars.roles_dependencies = {}
        vars.roles_dependants = {}
        return e_register_role:new(2, ...)
    end
    local mod = package.loaded[module_name]
    if type(mod) == 'table' and vars.known_roles[mod.role_name] then
        -- Already loaded
        return mod
    end

    local mod, err = e_register_role:pcall(require, module_name)
    if not mod then
        return nil, e(err)
    elseif type(mod) ~= 'table' then
        return nil, e('Module %q must return a table', module_name)
    end

    if mod.role_name == nil then
        mod.role_name = module_name
    end

    if type(mod.role_name) ~= 'string' then
        return nil, e('Module %q role_name must be a string', module_name)
    end

    if vars.known_roles[mod.role_name] ~= nil then
        return nil, e('Role %q name clash', mod.role_name)
    end

    local dependencies = mod.dependencies or {}
    if type(dependencies) ~= 'table' then
        return nil, e('Module %q dependencies must be a table', module_name)
    end

    vars.roles_dependencies[mod.role_name] = {}
    vars.roles_dependants[mod.role_name] = {}
    vars.known_roles[mod.role_name] = mod

    local function deps_append(tbl, deps)
        for _, dep in pairs(deps) do
            if not utils.table_find(tbl, dep) then
                table.insert(tbl, dep)
            end
        end
    end

    for _, dep_name in ipairs(dependencies) do
        local dep_mod, err = register_role(dep_name)
        if not dep_mod then
            return nil, err
        end

        deps_append(
            vars.roles_dependencies[mod.role_name],
            {dep_mod.role_name}
        )
        deps_append(
            vars.roles_dependencies[mod.role_name],
            vars.roles_dependencies[dep_mod.role_name]
        )

        deps_append(
            vars.roles_dependants[dep_mod.role_name],
            {mod.role_name}
        )
    end

    if utils.table_find(vars.roles_dependencies[mod.role_name], mod.role_name) then
        return nil, e('Module %q circular dependency not allowed', module_name)
    end
    topology.add_known_role(mod.role_name)
    vars.known_roles[#vars.known_roles+1] = mod

    return mod
end

--- List all registered roles names.
--
-- Hidden roles are not listed as well as permanent ones.
--
-- @function get_known_roles
-- @local
-- @treturn {string,..}
local function get_known_roles()
    local ret = {}

    for _, mod in ipairs(vars.known_roles) do
        if not (mod.permanent or mod.hidden) then
            table.insert(ret, mod.role_name)
        end
    end

    return ret
end

--- Roles to be enabled on the server.
-- This function returns all roles that will be enabled
-- including their dependencies (bot hidden and not)
-- and permanent roles.
--
-- @function get_enabled_roles
-- @local
-- @tparam {string,...}|{[string]=boolean,...} roles
-- @treturn {[string]=boolean,...}
local function get_enabled_roles(roles)
    checks('?table')

    if roles == nil then
        return {}
    end

    local ret = {}

    for _, mod in ipairs(vars.known_roles) do
        if mod.permanent then
            ret[mod.role_name] = true
        end
    end

    for k, v in pairs(roles) do
        local role_name, enabled
        if type(k) == 'number' and type(v) == 'string' then
            role_name, enabled = v, true
        else
            role_name, enabled = k, v
        end

        repeat -- until true
            if not enabled then
                break
            end

            ret[role_name] = true

            local deps = vars.roles_dependencies[role_name]
            if deps == nil then
                break
            end

            for _, dep_name in ipairs(deps) do
                ret[dep_name] = true
            end
        until true
    end

    return ret
end

--- List role dependencies.
-- Including sub-dependencies.
--
-- @function get_role_dependencies
-- @local
-- @tparam string role_name
-- @treturn {string,..}
local function get_role_dependencies(role_name)
    checks('?string')
    local ret = {}

    for _, dep_name in ipairs(vars.roles_dependencies[role_name]) do
        local mod = vars.known_roles[dep_name]
        if not (mod.permanent or mod.hidden) then
            table.insert(ret, mod.role_name)
        end
    end

    return ret
end


--- Load configuration from the filesystem.
-- Configuration is a YAML file.
-- @function load_from_file
-- @local
-- @tparam ?string filename Filename to load.
-- When omitted, the active configuration is loaded from `<workdir>/config.yml`.
-- @treturn[1] table
-- @treturn[2] nil
-- @treturn[2] table Error description
local function load_from_file(filename)
    checks('?string')
    filename = filename or fio.pathjoin(vars.workdir, 'config.yml')

    if not utils.file_exists(filename) then
        return nil, e_config_load:new('file %q does not exist', filename)
    end

    local raw, err = utils.file_read(filename)
    if not raw then
        return nil, err
    end

    local confdir = fio.dirname(filename)

    local conf, err = e_yaml:pcall(yaml.decode, raw)
    if not conf then
        if not err then
            return nil, e_config_load:new('file %q is empty', filename)
        end

        return nil, err
    end

    local function _load(tbl)
        for k, v in pairs(tbl) do
            if type(v) == 'table' then
                local err
                if v['__file'] then
                    tbl[k], err = utils.file_read(confdir .. '/' .. v['__file'])
                else
                    tbl[k], err = _load(v)
                end
                if err then
                    return nil, err
                end
            end
        end
        return tbl
    end

    local conf, err = _load(conf)

    return conf, err
end

--- Get a read-only view on the clusterwide configuration.
--
-- Returns either `conf[section_name]` or entire `conf`.
-- Any attempt to modify the section or its children
-- will raise an error.
-- @function get_readonly
-- @tparam[opt] string section_name
-- @treturn table
local function get_readonly(section_name)
    checks('?string')
    if vars.conf == nil then
        return nil
    elseif section_name == nil then
        return vars.conf
    else
        return vars.conf[section_name]
    end
end

--- Get a read-write deep copy of the clusterwide configuration.
--
-- Returns either `conf[section_name]` or entire `conf`.
-- Changing it has no effect
-- unless it's used to patch clusterwide configuration.
-- @function get_deepcopy
-- @tparam[opt] string section_name
-- @treturn table
local function get_deepcopy(section_name)
    checks('?string')

    if vars.conf == nil then
        return nil
    end

    local ret
    if section_name == nil then
        ret = vars.conf
    else
        ret = vars.conf[section_name]
    end

    ret = table.deepcopy(ret)

    if type(ret) == 'table' then
        return utils.table_setrw(ret)
    else
        return ret
    end
end

local function fetch_from_uri(uri)
    local conn, err = pool.connect(uri)
    if conn == nil then
        return nil, err
    end

    return errors.netbox_call(
        conn,
        '_G.__cluster_confapplier_load_from_file'
    )
end

--- Fetch configuration from another instance.
-- @function fetch_from_membership
-- @local
local function fetch_from_membership(topology_cfg)
    checks('?table')
    if topology_cfg ~= nil then
        if topology_cfg.servers[box.info.uuid] == nil
        or topology_cfg.servers[box.info.uuid] == 'expelled'
        or utils.table_count(topology_cfg.servers) == 1
        then
            return load_from_file()
        end
    end

    local candidates = {}
    for uri, member in membership.pairs() do
        if (member.status ~= 'alive') -- ignore non-alive members
        or (member.payload.uuid == nil)  -- ignore non-configured members
        or (member.payload.error ~= nil) -- ignore misconfigured members
        or (topology_cfg and member.payload.uuid == box.info.uuid) -- ignore myself
        or (topology_cfg and topology_cfg.servers[member.payload.uuid] == nil) -- ignore aliens
        -- luacheck: ignore 542
        then
            -- ignore that member
        else

            table.insert(candidates, uri)
        end
    end

    if #candidates == 0 then
        return nil
    end

    return e_config_fetch:pcall(fetch_from_uri, candidates[math.random(#candidates)])
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table conf_new
-- @tparam table conf_old
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(conf_new, conf_old)
    if type(conf_new) ~= 'table'  then
        return nil, e_config_validate:new('config must be a table')
    end
    checks('table', 'table')

    for _, mod in ipairs(vars.known_roles) do
        if type(mod.validate_config) == 'function' then
            local ok, err = e_config_validate:pcall(
                mod.validate_config, conf_new, conf_old
            )
            if not ok then
                err = err or e_config_validate:new(
                    'Role %q method validate_config() returned %s',
                    mod.role_name, ok
                )
                return nil, err
            end
        elseif type(mod.validate) == 'function' then
            log.warn(
                'Role %q method "validate()" is deprecated. ' ..
                'Use "validate_config()" instead.',
                mod.role_name
            )
            local ok, err = e_config_validate:pcall(
                mod.validate, conf_new, conf_old
            )
            if not ok then
                err = err or e_config_validate:new(
                    'Role %q method validate() returned %s',
                    mod.role_name, ok
                )
                return nil, err
            end
        end
    end

    return true
end

local function _failover_role(mod, opts)
    if service_registry.get(mod.role_name) == nil then
        return true
    end

    if type(mod.apply_config) ~= 'function' then
        return true
    end

    if type(mod.validate_config) == 'function' then
        local ok, err = e_config_validate:pcall(
            mod.validate_config, vars.conf, vars.conf
        )
        if not ok then
            err = err or e_config_validate:new('validate_config() returned %s', ok)
            return nil, err
        end
    end

    return e_config_apply:pcall(
        mod.apply_config, vars.conf, opts
    )
end

local function _failover(cond)
    local function failover_internal()
        local my_replicaset = vars.conf.topology.replicasets[box.info.cluster.uuid]
        local active_masters = topology.get_active_masters()
        local is_master = false
        if active_masters[box.info.cluster.uuid] == box.info.uuid then
            is_master = true
        end
        local opts = utils.table_setro({is_master = is_master})

        local is_rw = is_master or my_replicaset.all_rw
        local _, err = e_config_apply:pcall(box.cfg, {
            read_only = not is_rw,
        })
        if err then
            log.error('Box.cfg failed: %s', err)
        end

        for _, mod in ipairs(vars.known_roles) do
            local _, err = _failover_role(mod, opts)
            if err then
                log.error('Role %q failover failed: %s', mod.role_name, err)
            end
        end

        log.info('Failover step finished')
        return true
    end

    while true do
        cond:wait()
        local ok, err = e_failover:pcall(failover_internal)
        if not ok then
            log.warn('%s', err)
        end
    end
end

--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(conf)
    checks('table')
    vars.conf = utils.table_setro(conf)
    box.session.su('admin')

    local replication = topology.get_replication_config(
        conf.topology,
        box.info.cluster.uuid
    )

    topology.set(conf.topology)
    local my_replicaset = conf.topology.replicasets[box.info.cluster.uuid]
    local active_masters = topology.get_active_masters()
    local is_master = false
    if active_masters[box.info.cluster.uuid] == box.info.uuid then
        is_master = true
    end

    local is_rw = is_master or my_replicaset.all_rw

    local _, err = e_config_apply:pcall(box.cfg, {
        read_only = not is_rw,
        -- workaround for tarantool gh-3760
        replication_connect_timeout = 0.000001,
        replication_connect_quorum = 0,
        replication = replication,
    })
    if err then
        log.error('Box.cfg failed: %s', err)
    end

    local enabled_roles = get_enabled_roles(my_replicaset.roles)
    for _, mod in ipairs(vars.known_roles) do
        local role_name = mod.role_name
        if enabled_roles[role_name] then
            repeat -- until true
                if (service_registry.get(role_name) == nil)
                and (type(mod.init) == 'function')
                then
                    local _, _err = e_config_apply:pcall(mod.init,
                        {is_master = is_master}
                    )
                    if _err then
                        log.error('%s', _err)
                        err = err or _err
                        break
                    end
                end

                service_registry.set(role_name, mod)

                if type(mod.apply_config) == 'function' then
                    local _, _err = e_config_apply:pcall(
                        mod.apply_config, conf,
                        {is_master = is_master}
                    )
                    if _err then
                        log.error('%s', _err)
                        err = err or _err
                    end
                end
            until true
        else
            if (service_registry.get(role_name) ~= nil)
            and (type(mod.stop) == 'function')
            then
                local _, _err = e_config_apply:pcall(mod.stop,
                        {is_master = is_master}
                )
                if _err then
                    log.error('%s', err)
                    err = err or _err
                end
            end

            service_registry.set(role_name, nil)
        end
    end
    log.info('Config applied')

    local failover_enabled = conf.topology.failover
    local failover_running = vars.failover_fiber and vars.failover_fiber:status() ~= 'dead'

    if failover_enabled and not failover_running then
        vars.failover_cond = membership.subscribe()
        vars.failover_fiber = fiber.create(_failover, vars.failover_cond)
        vars.failover_fiber:name('cluster.failover')
        log.info('Failover enabled')
    elseif not failover_enabled and failover_running then
        membership.unsubscribe(vars.failover_cond)
        vars.failover_fiber:cancel()
        vars.failover_fiber = nil
        vars.failover_cond = nil
        log.info('Failover disabled')
    end

    if err then
        membership.set_payload('error', 'Config apply failed')
        return nil, err
    else
        membership.set_payload('ready', true)
        return true
    end
end

_G.__cluster_confapplier_load_from_file = load_from_file

return {
    set_workdir = set_workdir,
    get_workdir = function() return vars.workdir end,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    load_from_file = load_from_file,
    fetch_from_membership = fetch_from_membership,

    register_role = register_role,
    get_known_roles = get_known_roles,
    get_enabled_roles = get_enabled_roles,
    get_role_dependencies = get_role_dependencies,

    apply_config = apply_config,
    validate_config = validate_config,
}
