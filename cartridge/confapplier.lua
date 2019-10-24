#!/usr/bin/env tarantool

--- Configuration management primitives.
-- This module manages current instance state.
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
local remote_control = require('cartridge.remote-control')
local cluster_cookie = require('cartridge.cluster-cookie')
local service_registry = require('cartridge.service-registry')
local ClusterwideConfig = require('cartridge.clusterwide-config')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local e_yaml = errors.new_class('Parsing yaml failed')
local e_atomic = errors.new_class('Atomic call failed')
local e_failover = errors.new_class('Failover failed')
local e_config_load = errors.new_class('Loading configuration failed')
local e_config_fetch = errors.new_class('Fetching configuration failed')
local e_config_apply = errors.new_class('Applying configuration failed')
local e_config_validate = errors.new_class('Invalid config')
local e_register_role = errors.new_class('Can not register role')
local BoxError = errors.new_class('BoxError', {log_on_creation = true})
local BootError = errors.new_class('BootError', {log_on_creation = true})
local StateError = errors.new_class('StateError', {log_on_creation = true})

vars:new('state', '')
vars:new('error')
vars:new('cwcfg') -- clusterwide config

vars:new('workdir')
vars:new('instance_uuid')
vars:new('replicaset_uuid')

vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

vars:new('box_opts', nil)
vars:new('boot_opts', nil)

local _transitions = {
    -- Initial state.
    -- Function `confapplier.init()` wasn't called yet.
    [''] = {'Unconfigured', 'ConfigFound', 'Error'},

-- init()
    -- Remote control is running.
    -- Clusterwide config doesn't exist.
    ['Unconfigured'] = {'BootstrappingBox', 'Error'},

    -- Remote control is running.
    -- Clusterwide config is found
    ['ConfigFound'] = {'ConfigLoaded', 'Error'},
    -- Remote control is running.
    -- Loading clusterwide config succeeded.
    -- Validation succeeded too.
    ['ConfigLoaded'] = {'RecoveringSnapshot', 'Error'},

-- boot_instance
    -- Remote control is running.
    -- Clusterwide config is loaded.
    -- Remote control initiated `boot_instance()`
    ['BootstrappingBox'] = {'BoxConfigured', 'Error'},

    -- Remote control is running.
    -- Clusterwide config is loaded.
    -- Function `confapplier.init()` initiated `boot_instance()`
    ['RecoveringSnapshot'] = {'BoxConfigured', 'Error'},

    -- Remote control is stopped.
    -- Recovering snapshot finished.
    -- Box is listening binary port.
    ['BoxConfigured'] = {'RolesConfigured', 'Error'},

-- normal operation
    ['RolesConfigured'] = {'RolesConfigured', 'Error'},
    ['Error'] = {},
    -- Disabled
    -- Expelled
}
local function set_state(new_state, err)
    checks('string', '?')
    StateError:assert(
        utils.table_find(_transitions[vars.state], new_state),
        'invalid transition %s -> %s', vars.state, new_state
    )

    if new_state == 'Error' then
        log.error('Instance entering failure state:\n\t%s', err)
        vars.error = err
    elseif new_state ~= vars.state then
        log.warn('Instance state changed: %s -> %s',
            vars.state, new_state
        )
    end
    vars.state = new_state
end
local function assert_transition(new_state)
    StateError:assert(
        utils.table_find(_transitions[vars.state], new_state),
        'invalid state %s -> %s', vars.state, new_state
    )
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table cwcfg_new
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)

    return roles.validate_config(
        cwcfg:get_readonly(),
        vars.cwcfg and vars.cwcfg:get_readonly() or {}
    )
end


--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)
    assert(
        vars.state == 'BoxConfigured'
        or vars.state == 'RolesConfigured',
        'Unexpected state ' .. vars.state
    )

    vars.cwcfg = cwcfg
    -- box.session.su('admin')

    local read_only
    if nil then
        -- my_replicaset.all_rw
        -- is_leader
        -- failover.is_leader()
    end

    local _, err = BoxError:pcall(box.cfg, {
        replication = topology.get_replication_config(
            cwcfg, vars.replicaset_uuid
        ),
        read_only = read_only,
    })
    if err then
        set_state('Error', err)
        return nil, err
    end

    local ok, err = roles.apply_config(cwcfg:get_readonly())
    if not ok then
        set_state('Error', err)
        return nil, err
    end

    set_state('RolesConfigured')
    return true
end


local function boot_instance(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)
    assert(
        vars.state == 'Unconfigured' -- bootstraping from scratch
        or vars.state == 'ConfigLoaded', -- bootstraping from snapshot
        'Unexpected state ' .. vars.state
    )

    local box_opts = table.deepcopy(vars.box_opts)
    box_opts.wal_dir = vars.workdir
    box_opts.memtx_dir = vars.workdir
    box_opts.vinyl_dir = vars.workdir
    box_opts.listen = box.NULL

    if vars.state == 'Unconfigured' then
        set_state('BootstrappingBox')

        local advertise_uri = membership.myself().uri
        local instance_uuid, server =
            topology.find_server_by_uri(cwcfg, advertise_uri)

        if instance_uuid == nil then
            local err = BootError:new(
                "Couldn't find %s in clusterwide config," ..
                " bootstrap impossible",
                advertise_uri
            )
            set_state('Error', err)
            return nil, err
        end

        box_opts.instance_uuid = instance_uuid
        box_opts.replicaset_uuid = server.replicaset_uuid

        local topology_cfg = cwcfg:get_readonly('topology')
        local leaders_order = topology.get_leaders_order(
            topology_cfg,
            box_opts.replicaset_uuid
        )
        local leader_uuid = leaders_order[1]
        local leader = topology_cfg.servers[leader_uuid]

        local ro
        if box_opts.instance_uuid ~= leader_uuid then
            box_opts.replication = {pool.format_uri(leader.uri)}
            ro = true
        else
            box_opts.replication = nil
            ro = false
        end

        if box_opts.read_only == nil then
            box_opts.read_only = ro
        end

    elseif vars.state == 'ConfigLoaded' then
        set_state('RecoveringSnapshot')

        local snapshots = fio.glob(fio.pathjoin(vars.workdir, '*.snap'))
        if next(snapshots) == nil then
            local err = BootError:new(
                "Snapshot not found in %q, can't recover." ..
                " Did previous bootstrap attempt fail?",
                vars.workdir
            )
            set_state('Error', err)
            return nil, err
        end

        if box_opts.read_only == nil then
            box_opts.read_only = true
        end
    end

    log.warn('Calling box.cfg()...')
    -- This operation may be long
    -- It recovers snapshot
    -- Or bootstraps replication
    box.cfg(box_opts)

    local username = cluster_cookie.username()
    local password = cluster_cookie.cookie()

    log.info('Making sure user %q exists...', username)
    if not box.schema.user.exists(username) then
        -- Quite impossible assert just in case
        error(('User %q does not exists'):format(username))
    end

    if not box.cfg.read_only then
        log.info('Granting replication permissions to %q...', username)

        BoxError:pcall(
            box.schema.user.grant,
            username, 'replication',
            nil, nil, {if_not_exists = true}
        )


        log.info('Setting password for user %q ...', username)
        BoxError:pcall(
            box.schema.user.passwd,
            username, password
        )
    end

    remote_control.stop()
    local _, err = BoxError:pcall(
        box.cfg, {listen = vars.binary_port}
    )

    if err ~= nil then
        set_state('Error', err)
        return nil, err
    end

    vars.instance_uuid = box.info.uuid
    vars.replicaset_uuid = box.info.cluster.uuid
    membership.set_payload('uuid', box.info.uuid)

    set_state('BoxConfigured')
    return apply_config(cwcfg)
end

local function init(opts)
    checks({
        workdir = 'string',
        box_opts = 'table',
        binary_port = 'number',
    })

    assert(vars.state == '', 'Unexpected state ' .. vars.state)
    vars.workdir = opts.workdir
    vars.box_opts = opts.box_opts
    vars.binary_port = opts.binary_port

    local ok, err = remote_control.start('0.0.0.0', vars.binary_port, {
        username = cluster_cookie.username(),
        password = cluster_cookie.cookie(),
    })
    if not ok then
        set_state('Error', err)
        return nil, err
    end

    local config_filename = fio.pathjoin(vars.workdir, 'config.yml')
    if not utils.file_exists(config_filename) then
        set_state('Unconfigured')
        -- boot_instance() will be called later over remote control
    else
        set_state('ConfigFound')
        local cwcfg, err = ClusterwideConfig.load_from_file(config_filename)
        if cwcfg == nil then
            set_state('Error', err)
            return nil, err
        end

        vars.cwcfg = cwcfg:lock()
        local ok, err = validate_config(cwcfg)
        if not ok then
            set_state('Error', err)
            return nil, err
        end

        set_state('ConfigLoaded')
        fiber.new(boot_instance, cwcfg)
    end

    return true
end

-- local function _failover_role(mod, opts)
--     if service_registry.get(mod.role_name) == nil then
--         return true
--     end

--     if type(mod.apply_config) ~= 'function' then
--         return true
--     end

--     if type(mod.validate_config) == 'function' then
--         local ok, err = e_config_validate:pcall(
--             mod.validate_config, vars.conf, vars.conf
--         )
--         if not ok then
--             err = err or e_config_validate:new('validate_config() returned %s', ok)
--             return nil, err
--         end
--     end

--     return e_config_apply:pcall(
--         mod.apply_config, vars.conf, opts
--     )
-- end

local function get_active_config()
    return vars.cwcfg
end

local function get_readonly(section)
    checks('?string')
    if vars.cwcfg == nil then
        return nil
    end
    return vars.cwcfg:get_readonly(section)
end

local function get_deepcopy(section)
    checks('?string')
    if vars.cwcfg == nil then
        return nil
    end
    return vars.cwcfg:get_deepcopy(section)
end

local function get_state()
    return vars.state, vars.error
end

-- local function _failover(cond)
--     local function failover_internal()
--         local active_masters = topology.get_active_masters()
--         local is_master = false
--         if active_masters[box.info.cluster.uuid] == box.info.uuid then
--             is_master = true
--         end
--         local opts = utils.table_setro({is_master = is_master})

--         local _, err = e_config_apply:pcall(box.cfg, {
--             read_only = not is_master,
--         })
--         if err then
--             log.error('Box.cfg failed: %s', err)
--         end

--         for _, mod in ipairs(vars.known_roles) do
--             local _, err = _failover_role(mod, opts)
--             if err then
--                 log.error('Role %q failover failed: %s', mod.role_name, err)
--             end
--         end

--         log.info('Failover step finished')
--         return true
--     end

--     while true do
--         cond:wait()
--         local ok, err = e_failover:pcall(failover_internal)
--         if not ok then
--             log.warn('%s', err)
--         end
--     end
-- end

return {
    init = init,
    boot_instance = boot_instance,

    get_active_config = get_active_config,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    get_state = get_state,
    get_workdir = function() return vars.workdir end,
    apply_config = apply_config,
    validate_config = validate_config,
}
