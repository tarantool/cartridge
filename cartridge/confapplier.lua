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
local failover = require('cartridge.failover')
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
local BoxError = errors.new_class('BoxError')
local InitError = errors.new_class('InitError')
local BootError = errors.new_class('BootError')
local StateError = errors.new_class('StateError')

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
-- init()
    -- Initial state.
    -- Function `confapplier.init()` wasn't called yet.
    [''] = {'Unconfigured', 'ConfigFound', 'InitError'},

    -- Remote control is running.
    -- Clusterwide config doesn't exist.
    ['Unconfigured'] = {'BootstrappingBox'},

    -- Remote control is running.
    -- Clusterwide config is found
    ['ConfigFound'] = {'ConfigLoaded', 'InitError'},
    -- Remote control is running.
    -- Loading clusterwide config succeeded.
    -- Validation succeeded too.
    ['ConfigLoaded'] = {'RecoveringSnapshot'},

-- boot_instance
    -- Remote control is running.
    -- Clusterwide config is loaded.
    -- Remote control initiated `boot_instance()`
    ['BootstrappingBox'] = {'BoxConfigured', 'BootError'},

    -- Remote control is running.
    -- Clusterwide config is loaded.
    -- Function `confapplier.init()` initiated `boot_instance()`
    ['RecoveringSnapshot'] = {'BoxConfigured', 'BootError'},

    -- Remote control is stopped.
    -- Recovering snapshot finished.
    -- Box is listening binary port.
    ['BoxConfigured'] = {'ConnectingFullmesh'},

-- normal operation
    ['ConnectingFullmesh'] = {'ConfiguringRoles', 'OperationError'},
    ['ConfiguringRoles'] = {'RolesConfigured', 'OperationError'},
    ['RolesConfigured'] = {'ConnectingFullmesh'},

-- errors
    ['InitError'] = {},
    ['BootError'] = {},
    ['OperationError'] = {}, -- {'BoxConfigured'}
    -- Disabled
    -- Expelled
}
local function set_state(new_state, err)
    checks('string', '?')
    StateError:assert(
        utils.table_find(_transitions[vars.state], new_state),
        'invalid transition %s -> %s', vars.state, new_state
    )

    if new_state == 'InitError'
    or new_state == 'BootError'
    or new_state == 'OperationError'
    then
        log.error('Instance entering failed state: %s -> %s\n%s',
            vars.state, new_state, err
        )
    else
        log.info('Instance state changed: %s -> %s',
            vars.state, new_state
        )
    end

    vars.state = new_state
    vars.error = err
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

    set_state('ConnectingFullmesh')
    box.cfg({
        replication_connect_quorum = 0,
        -- replication_connect_timeout = 0.01,
    })
    local _, err = BoxError:pcall(box.cfg, {
        replication = topology.get_fullmesh_replication(
            cwcfg:get_readonly('topology'), vars.replicaset_uuid
        ),
    })
    if err then
        set_state('OperationError', err)
        return nil, err
    end

    failover.cfg(cwcfg)

    set_state('ConfiguringRoles')
    local ok, err = roles.apply_config(cwcfg:get_readonly())
    if not ok then
        set_state('OperationError', err)
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

    local topology_cfg = cwcfg:get_readonly('topology') or {}
    local box_opts = table.deepcopy(vars.box_opts)
    box_opts.wal_dir = vars.workdir
    box_opts.memtx_dir = vars.workdir
    box_opts.vinyl_dir = vars.workdir
    box_opts.listen = box.NULL
    if box_opts.read_only == nil then
        box_opts.read_only = true
    end

    if vars.state == 'ConfigLoaded' then
        set_state('RecoveringSnapshot')

        local snapshots = fio.glob(fio.pathjoin(vars.workdir, '*.snap'))
        if next(snapshots) == nil then
            local err = BootError:new(
                "Snapshot not found in %s, can't recover." ..
                " Did previous bootstrap attempt fail?",
                vars.workdir
            )
            set_state('BootError', err)
            return nil, err
        end

    elseif vars.state == 'Unconfigured' then
        set_state('BootstrappingBox')

        local advertise_uri = membership.myself().uri
        local instance_uuid, server = topology.find_server_by_uri(
            topology_cfg, advertise_uri
        )
        local replicaset_uuid = server and server.replicaset_uuid

        if instance_uuid == nil then
            local err = BootError:new(
                "Couldn't find server %s in clusterwide config," ..
                " bootstrap impossible",
                advertise_uri
            )
            set_state('BootError', err)
            return nil, err
        else
            assert(replicaset_uuid ~= nil)
        end

        box_opts.instance_uuid = instance_uuid
        box_opts.replicaset_uuid = replicaset_uuid

        local leaders_order = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
        local leader_uuid = leaders_order[1]
        local leader = topology_cfg.servers[leader_uuid]

        if box_opts.instance_uuid == leader_uuid then
            box_opts.replication = nil
            box_opts.read_only = false
        else
            box_opts.replication = {pool.format_uri(leader.uri)}
            -- box_opts.read_only = true
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

    if vars.state == 'BootstrappingBox' then
        log.info('Granting replication permissions to %q...', username)

        BoxError:pcall(
            box.schema.user.grant,
            username, 'replication',
            nil, nil, {if_not_exists = true}
        )
    end

    do
        log.info('Setting password for user %q ...', username)

        local read_only = box.cfg.read_only
        box.cfg({read_only = false})

        BoxError:pcall(
            box.schema.user.passwd,
            username, password
        )

        box.cfg({read_only = read_only})
    end

    remote_control.stop()
    local _, err = BoxError:pcall(
        box.cfg, {listen = vars.binary_port}
    )

    if err ~= nil then
        set_state('BootError', err)
        return nil, err
    end

    vars.instance_uuid = box.info.uuid
    vars.replicaset_uuid = box.info.cluster.uuid
    membership.set_payload('uuid', box.info.uuid)

    if topology_cfg.servers == nil
    or topology_cfg.servers[vars.instance_uuid] == nil
    then
        local err = BootError:new(
            "Server %s not in clusterwide config," ..
            " no idea what to do now",
            vars.instance_uuid
        )
        set_state('BootError', err)
        return nil, err
    end

    if topology_cfg.replicasets == nil
    or topology_cfg.replicasets[vars.replicaset_uuid] == nil
    then
        local err = BootError:new(
            "Replicaset %s not in clusterwide config," ..
            " no idea what to do now",
            vars.replicaset_uuid
        )
        set_state('BootError', err)
        return nil, err
    end

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
        set_state('InitError', err)
        return nil, err
    else
        log.info('Remote control listening on 0.0.0.0:%d', vars.binary_port)
    end

    local config_filename = fio.pathjoin(vars.workdir, 'config.yml')
    if not utils.file_exists(config_filename) then
        local snapshots = fio.glob(fio.pathjoin(vars.workdir, '*.snap'))
        if next(snapshots) ~= nil then
            local err = InitError:new(
                "Snapshot was found in %s, but config.yml wasn't." ..
                " Where did it go?",
                vars.workdir
            )
            set_state('InitError', err)
            return true
        end

        set_state('Unconfigured')
        -- boot_instance() will be called over net.box later
    else
        set_state('ConfigFound')
        local cwcfg, err = ClusterwideConfig.load_from_file(config_filename)
        if cwcfg == nil then
            set_state('InitError', err)
            return true
        end

        -- TODO validate vshard groups

        vars.cwcfg = cwcfg:lock()
        local ok, err = validate_config(cwcfg)
        if not ok then
            set_state('InitError', err)
            return true
        end

        set_state('ConfigLoaded')
        fiber.new(boot_instance, cwcfg)
    end

    return true
end

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

return {
    init = init,
    boot_instance = boot_instance,
    apply_config = apply_config,
    validate_config = validate_config,

    get_active_config = get_active_config,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    get_state = get_state,
    get_workdir = function() return vars.workdir end,
}
