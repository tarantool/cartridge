#!/usr/bin/env tarantool
-- luacheck: globals box

--- Clusterwide configuration management primitives.
-- @module cluster.confapplier

local log = require('log')
local fio = require('fio')
local yaml = require('yaml').new()
local fiber = require('fiber')
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')
local vshard = require('vshard')
local membership = require('membership')

local vars = require('cluster.vars').new('cluster.confapplier')
local pool = require('cluster.pool')
local utils = require('cluster.utils')
local topology = require('cluster.topology')
local service_registry = require('cluster.service-registry')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local e_yaml = errors.new_class('Parsing yaml failed')
local e_atomic = errors.new_class('Atomic call failed')
local e_rollback = errors.new_class('Rollback failed')
local e_failover = errors.new_class('Vshard failover failed')
local e_config_load = errors.new_class('Loading configuration failed')
local e_config_fetch = errors.new_class('Fetching configuration failed')
local e_config_apply = errors.new_class('Applying configuration failed')
local e_config_restore = errors.new_class('Restoring configuration failed')
local e_config_validate = errors.new_class('Invalid config')
local e_register_role = errors.new_class('Can not register role')
local e_bootstrap_vshard = errors.new_class('Can not bootstrap vshard router now')

vars:new('conf')
vars:new('workdir')
vars:new('locks', {})
vars:new('known_roles', {})
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
    local mod, err = e_register_role:pcall(require, module_name)
    if not mod then
        return nil, err
    end

    mod.role_name = mod.role_name or module_name
    if utils.table_find(vars.known_roles, mod.role_name) then
        return nil, e_register_role:new('Role %q is already registered', mod.role_name)
    end

    topology.add_known_role(mod.role_name)
    table.insert(vars.known_roles, mod)
    return true
end

local function get_known_roles()
    local ret = {
        'vshard-storage',
        'vshard-router',
    }

    for _, mod in ipairs(vars.known_roles) do
        table.insert(ret, mod.role_name)
    end

    return ret
end

--- Load config from filesystem.
-- Config is a YAML file.
-- @function load_from_file
-- @tparam ?string filename Filename to load.
-- When ommited active config is loaded from `<workdir>/config.yml`.
-- @treturn table|nil Config loaded
-- @treturn ?error Error description
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

local mt_readonly = {
    __newindex = function()
        error('table is read-only')
    end
}

--- Recursively change table read-only property.
-- This is achieved by setting or removing a metatable.
-- An attempt to modify the read-only table or any of its children
-- would raise an error: "table is read-only".
-- @function set_readonly
-- @local
-- @tparam table tbl A table to be processed
-- @tparam boolean ro Desired readonliness
-- @treturn table the same table `tbl`
local function set_readonly(tbl, ro)
    checks("table", "boolean")

    for _, v in pairs(tbl) do
        if type(v) == 'table' then
            set_readonly(v, ro)
        end
    end

    if ro then
        setmetatable(tbl, mt_readonly)
    else
        setmetatable(tbl, nil)
    end

    return tbl
end

--- Get read-only view of a config section.
-- Any attempt to modify the section or its children
-- will raise the error "table is read-only"
-- @function get_readonly
-- @tparam string section_name A name of a section
-- @treturn table Read-only view on `cfg[section_name]`
local function get_readonly(section_name)
    checks('string')
    if vars.conf == nil then
        return nil
    end
    return vars.conf[section_name]
end

--- Get read-write deepcopy of a config section.
-- Changing the section has no effect
-- unless it is passed to a `patch_clusterwide` call.
-- @function get_deepcopy
-- @tparam string section_name A name of a section
-- @treturn table Deep copy of `cfg[section_name]`
local function get_deepcopy(section_name)
    checks('string')
    if vars.conf == nil then
        return nil
    end

    local ret = table.deepcopy(vars.conf[section_name])

    if type(ret) == 'table' then
        return set_readonly(ret, false)
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

local function validate_config(conf_new, conf_old)
    if type(conf_new) ~= 'table'  then
        return nil, e_config_validate:new('config must be a table')
    end
    checks('table', 'table')

    if type(conf_new.vshard) ~= 'table' then
        return nil, e_config_validate:new('section "vshard" must be a table')
    elseif type(conf_new.vshard.bucket_count) ~= 'number' then
        return nil, e_config_validate:new('vshard.bucket_count must be a number')
    elseif not (conf_new.vshard.bucket_count > 0) then
        return nil, e_config_validate:new('vshard.bucket_count must be a positive')
    elseif type(conf_new.vshard.bootstrapped) ~= 'boolean' then
        return nil, e_config_validate:new('vshard.bootstrapped must be true or false')
    end

    for _, mod in ipairs(vars.known_roles) do
        if type(mod.validate_config) == 'function' then
            local ok, err = e_config_validate:pcall(
                mod.validate_config, conf_new, conf_old
            )
            if not ok then
                err = err or e_config_validate:new(
                    'Role %q vaildation failed', mod.role_name
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
                    'Role %q vaildation failed', mod.role_name
                )
                return nil, err
            end
        end
    end

    return true
end

local function _failover(cond)
    local function failover_internal()
        local active_masters = topology.get_active_masters()
        local is_master = false
        if active_masters[box.info.cluster.uuid] == box.info.uuid then
            is_master = true
        end

        local bucket_count = vars.conf.vshard.bucket_count
        local cfg_new = topology.get_vshard_sharding_config()
        local cfg_old = nil

        local vshard_router = service_registry.get('vshard-router')
        local vshard_storage = service_registry.get('vshard-storage')

        if vshard_router and vshard_router.internal.current_cfg then
            local cfg_old = vshard_router.internal.current_cfg.sharding
        elseif vshard_storage and vshard_storage.internal.current_cfg then
            local cfg_old = vshard_storage.internal.current_cfg.sharding
        end

        if not utils.deepcmp(cfg_new, cfg_old) then
            if vshard_storage then
                log.info('Reconfiguring vshard.storage...')
                local cfg = {
                    sharding = cfg_new,
                    listen = box.cfg.listen,
                    bucket_count = bucket_count,
                    -- replication_connect_quorum = 0,
                }
                local _, err = e_failover:pcall(vshard_storage.cfg, cfg, box.info.uuid)
                if err then
                    log.error('%s', err)
                end
            end

            if vshard_router then
                log.info('Reconfiguring vshard.router...')
                local cfg = {
                    sharding = cfg_new,
                    bucket_count = bucket_count,
                    -- replication_connect_quorum = 0,
                }
                local _, err = e_failover:pcall(vshard_router.cfg, cfg, box.info.uuid)
                if err then
                    log.error('%s', err)
                end
            end

            log.info('Failover step finished')
        end

        for _, mod in ipairs(vars.known_roles) do
            -- local role_name = mod.role_name
            if (service_registry.get(mod.role_name) ~= nil)
            and (type(mod.apply_config) == 'function')
            then
                local _, err = e_config_apply:pcall(
                    mod.apply_config, vars.conf,
                    {is_master = is_master}
                )
                if err then
                    log.error('%s', err)
                end
            end
        end

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

--- Apply roles config.
-- @function apply_config
-- @local
-- @tparam table conf Config to be applied
-- @treturn true|nil Success indication
-- @treturn ?error Error description
local function apply_config(conf)
    checks('table')
    vars.conf = set_readonly(conf, true)
    box.session.su('admin')

    local replication = topology.get_replication_config(
        conf.topology,
        box.info.cluster.uuid
    )
    log.info('Setting replication to [%s]', table.concat(replication, ', '))
    local _, err = e_config_apply:pcall(box.cfg, {
        -- workaround for tarantool gh-3760
        replication_connect_timeout = 0.000001,
        replication_connect_quorum = 0,
        replication = replication,
    })
    if err then
        log.error('Box.cfg failed: %s', err)
    end

    topology.set(conf.topology)
    local my_replicaset = conf.topology.replicasets[box.info.cluster.uuid]
    local roles_enabled = my_replicaset.roles
    local active_masters = topology.get_active_masters()
    local is_master = false
    if active_masters[box.info.cluster.uuid] == box.info.uuid then
        is_master = true
    end

    if roles_enabled['vshard-storage'] then
        vshard.storage.cfg({
            sharding = topology.get_vshard_sharding_config(),
            bucket_count = conf.vshard.bucket_count,
            listen = box.cfg.listen,
        }, box.info.uuid)
        service_registry.set('vshard-storage', vshard.storage)

        -- local srv = storage.new()
        -- srv:apply_config(conf)
    end

    if roles_enabled['vshard-router'] then
        -- local srv = ibcore.server.new()
        -- srv:apply_config(conf)
        -- service_registry.set('ib-core', srv)
        vshard.router.cfg({
            sharding = topology.get_vshard_sharding_config(),
            bucket_count = conf.vshard.bucket_count,
        })
        service_registry.set('vshard-router', vshard.router)
    end

    for _, mod in ipairs(vars.known_roles) do
        local role_name = mod.role_name
        if roles_enabled[role_name] then
            do
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
            end
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

    local failover_enabled = conf.topology.failover and (roles_enabled['vshard-storage'] or roles_enabled['vshard-router'])
    local failover_running = vars.failover_fiber and vars.failover_fiber:status() ~= 'dead'

    if failover_enabled and not failover_running then
        vars.failover_cond = membership.subscribe()
        vars.failover_fiber = fiber.create(_failover, vars.failover_cond)
        vars.failover_fiber:name('cluster.failover')
        log.info('vshard failover enabled')
    elseif not failover_enabled and failover_running then
        membership.unsubscribe(vars.failover_cond)
        vars.failover_fiber:cancel()
        vars.failover_fiber = nil
        vars.failover_cond = nil
        log.info('vshard failover disabled')
    end

    if err then
        membership.set_payload('error', 'Config apply failed')
        return nil, err
    else
        membership.set_payload('ready', true)
        return true
    end
end

--- Two-phase commit - prepare stage.
--
-- Validate config and aquire a lock writing `<workdir>/config.prepate.yml`.
-- If it fails, the lock is not aquired and does not have to be aborted.
-- @function prepare_2pc
-- @local
-- @tparam table conf A config table to be commited
-- @treturn true|nit Success indication
-- @treturn ?error Error description
local function prepare_2pc(conf)
    local ok, err = validate_config(conf, vars.conf or {})
    if not ok then
        return nil, err
    end

    local path = fio.pathjoin(vars.workdir, 'config.prepare.yml')
    local ok, err = utils.file_write(
        path, yaml.encode(conf),
        {'O_CREAT', 'O_EXCL', 'O_WRONLY'}
    )
    if not ok then
        return nil, err
    end

    return true
end

--- Two-phase commit - commit stage.
--
-- Backup active config, commit changes on filesystem, release a lock and configure roles.
-- If any error occurs, config is not rolled back automatically.
-- Any problem occured during this call has to be solved manually.
--
-- @function commit_2pc
-- @local
-- @treturn true|nil Success indication
-- @treturn ?error Error description
local function commit_2pc()
    local path_prepare = fio.pathjoin(vars.workdir, 'config.prepare.yml')
    local path_backup = fio.pathjoin(vars.workdir, 'config.backup.yml')
    local path_active = fio.pathjoin(vars.workdir, 'config.yml')

    fio.unlink(path_backup)
    local ok = fio.link(path_active, path_backup)
    if ok then
        log.info('Backup of active config created: %q', path_backup)
    end

    local ok = fio.rename(path_prepare, path_active)
    if not ok then
        local err = e_config_apply:new('Can not move %q: %s', path_prepare, errno.strerror())
        log.error('Error commmitting config update: %s', err)
        return nil, err
    end

    local conf, err = load_from_file()
    if not conf then
        log.error('Error commmitting config update: %s', err)
        return nil, err
    end

    return apply_config(conf)
end

--- Two-phase commit - abort stage.
--
-- Release a lock for further commit attempts.
-- @function abort_2pc
-- @local
-- @treturn true
local function abort_2pc()
    local path = fio.pathjoin(vars.workdir, 'config.prepare.yml')
    fio.unlink(path)
    return true
end

--- Edit clusterwide configuration.
-- Top-level keys are merged with currend config.
-- In order to remove a top-level section use
-- `patch_clusterwide{key = box.NULL}`
--
-- Two-phase commit algorithm is used.
-- In particular, the following steps are performed:
--
-- I. Current config is patched.
--
-- II. Topology is validated on current server.
--
-- III. Prepare phase (`prepare_2pc`) is executed on every server, excluding
-- expelled servers,
-- disabled server,
-- servers being joined during this call;
--
-- IV. Abort phase (`abort_2pc`) is executed if any server reports an error.
-- All servers prepared so far are rolled back and unlocked.
--
-- V. Commited phase (`commit_2pc`) is performed.
-- In case it fails automatic rollback is impossible,
-- cluster should be repaired by hands.
--
-- @function patch_clusterwide
-- @tparam table conf A patch to be applied
-- @treturn true|nil Success indication
-- @treturn ?error Error description
local function _clusterwide(conf)
    checks('table')

    log.warn('Updating config clusterwide...')

    local conf_new = set_readonly(table.deepcopy(vars.conf), false)
    local conf_old = vars.conf
    for k, v in pairs(conf) do
        if v == box.NULL then
            conf_new[k] = nil
        else
            conf_new[k] = v
        end
    end

    local ok, err = topology.validate(conf_new.topology, conf_old.topology)
    if not ok then
        return nil, err
    end

    local servers_new = conf_new.topology.servers
    local servers_old = conf_old.topology.servers

    -- Prepare a server group to be configured
    local configured_uri_list = {}
    local cnt = 0
    for uuid, _ in pairs(servers_new) do
        if not topology.not_disabled(uuid, servers_new[uuid]) then
            -- ignore disabled servers
        elseif servers_old[uuid] == nil then
            -- new servers bootstrap themselves through membership
            -- dont call nex.box on them
        else
            local uri = servers_new[uuid].uri
            cnt = cnt + 1
            configured_uri_list[cnt] = uri
            configured_uri_list[uri] = false
        end
    end

    -- this is mostly for testing purposes
    -- it allows to determine apply order
    -- in real world it does not affect anything
    table.sort(configured_uri_list)

    -- 2PC prepare
    local _2pc_error = nil
    for _, uri in ipairs(configured_uri_list) do
        local conn, err = pool.connect(uri)
        if conn == nil then
            log.error('Error preparing for config update at %s', uri)
            _2pc_error = err
            break
        else
            local ok, err = errors.netbox_call(
                conn,
                '_G.__cluster_confapplier_prepare_2pc',
                {conf_new}, {timeout = 5}
            )
            if ok == true then
                log.warn('Prepared for config update at %s', uri)
                configured_uri_list[uri] = true
            else
                log.error('Error preparing for config update at %s: %s', uri, err)
                _2pc_error = err
                break
            end
        end
    end

    if _2pc_error == nil then
        -- 2PC commit
        for _, uri in ipairs(configured_uri_list) do
            local conn, err = pool.connect(uri)
            if conn == nil then
                log.error('Error commmitting config update at %s: %s', uri, err)
                _2pc_error = err
            else
                local ok, err = errors.netbox_call(
                    conn,
                    '_G.__cluster_confapplier_commit_2pc'
                )
                if ok == true then
                    log.warn('Committed config update at %s', uri)
                else
                    log.error('Error commmitting config update at %s: %s', uri, err)
                    _2pc_error = err
                end
            end
        end
    else
        -- 2PC abort
        for _, uri in ipairs(configured_uri_list) do
            if not configured_uri_list[uri] then
                break
            end

            local conn, err = pool.connect(uri)
            if conn == nil then
                log.error('Error aborting config update at %s: %s', uri, err)
            else
                local ok, err = errors.netbox_call(
                    conn,
                    '_G.__cluster_confapplier_abort_2pc'
                )
                if ok == true then
                    log.warn('Aborted config update at %s', uri)
                else
                    log.error('Error aborting config update at %s: %s', uri, err)
                end
            end
        end
    end

    if _2pc_error == nil then
        log.warn('Clusterwide config updated successfully')
        return true
    else
        log.error('Clusterwide config update failed')
        return nil, _2pc_error
    end
end

local function patch_clusterwide(conf)
    if vars.locks['clusterwide'] == true  then
        return nil, e_atomic:new('confapplier.clusterwide is already running')
    end

    box.session.su('admin')
    vars.locks['clusterwide'] = true
    local ok, err = e_config_apply:pcall(_clusterwide, conf)
    vars.locks['clusterwide'] = false

    return ok, err
end

_G.__cluster_confapplier_load_from_file = load_from_file
_G.__cluster_confapplier_prepare_2pc = prepare_2pc
_G.__cluster_confapplier_commit_2pc = commit_2pc
_G.__cluster_confapplier_abort_2pc = abort_2pc

return {
    set_workdir = set_workdir,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    load_from_file = load_from_file,
    fetch_from_membership = fetch_from_membership,

    register_role = register_role,
    get_known_roles = get_known_roles,

    prepare_2pc = prepare_2pc,
    commit_2pc = commit_2pc,
    abort_2pc = abort_2pc,

    apply_config = apply_config,
    validate_config = validate_config,
    patch_clusterwide = patch_clusterwide,
}
