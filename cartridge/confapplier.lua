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
local roles = require('cartridge.roles')
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

vars:new('conf')
vars:new('workdir')
vars:new('locks', {})
vars:new('applier_fiber', nil)
vars:new('applier_channel', nil)
vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

local function set_workdir(workdir)
    checks('string')
    vars.workdir = workdir
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

    return roles.validate_config(conf_new, conf_old)
end

local function _failover_role(mod, opts)
    checks('table', {is_master = 'boolean'})

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
        local all_roles = roles.get_all_roles()
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

        for _, role_name in ipairs(all_roles) do
            local mod = roles.get_role(role_name)
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

    local _, _err = roles.apply_config(conf, {is_master = is_master})
    if _err then
        err = err or _err
    end

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

    apply_config = apply_config,
    validate_config = validate_config,
}
