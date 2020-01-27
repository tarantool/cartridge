#!/usr/bin/env tarantool

--- Configuration management primitives.
--
-- Implements the internal state machine which helps to manage cluster
-- operation and protects from invalid state transitions.
--
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
local ddl_manager = require('cartridge.ddl-manager')
local remote_control = require('cartridge.remote-control')
local cluster_cookie = require('cartridge.cluster-cookie')
local ClusterwideConfig = require('cartridge.clusterwide-config')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local BoxError = errors.new_class('BoxError')
local InitError = errors.new_class('InitError')
local BootError = errors.new_class('BootError')
local StateError = errors.new_class('StateError')

vars:new('state', '')
vars:new('error')
vars:new('state_notification', fiber.cond())
vars:new('state_notification_timeout', 5)
vars:new('clusterwide_config')

vars:new('workdir')
vars:new('instance_uuid')
vars:new('replicaset_uuid')

vars:new('box_opts', nil)

local state_transitions = {
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
    ['ConfigLoaded'] = {'RecoveringSnapshot', 'BootstrappingBox'},

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
    ['RolesConfigured'] = {'ConfiguringRoles'},

-- errors
    ['InitError'] = {},
    ['BootError'] = {},
    ['OperationError'] = {}, -- {'BoxConfigured'}
    -- Disabled
    -- Expelled
}

--- Perform state transition.
-- @function set_state
-- @local
-- @tparam string state
--   New state
-- @param[opt] err
-- @treturn nil
local function set_state(new_state, err)
    checks('string', '?')
    StateError:assert(
        utils.table_find(state_transitions[vars.state], new_state),
        'invalid transition %s -> %s', vars.state, new_state
    )

    if new_state == 'InitError'
    or new_state == 'BootError'
    or new_state == 'OperationError'
    then
        if err == nil then
            err = errors.new(new_state, 'Unknown error')
        end

        log.error('Instance entering failed state: %s -> %s\n%s',
            vars.state, new_state, err
        )
    else
        log.info('Instance state changed: %s -> %s',
            vars.state, new_state
        )
    end

    membership.set_payload('state', new_state)
    vars.state = new_state
    vars.error = err
    vars.state_notification:signal()
end

--- Make a wish for meeting desired state.
-- @function wish_state
-- @local
-- @tparam string state
--   Desired state.
-- @tparam[opt] number timeout
-- @treturn string
--   Final state, may differ from desired.
local function wish_state(state, timeout)
    checks('string', '?number')
    if timeout == nil then
        timeout = vars.state_notification_timeout
    end

    local deadline = fiber.time() + timeout
    while fiber.time() < deadline do
        if vars.state == state then
            -- Wish granted
            break
        elseif not utils.table_find(state_transitions[vars.state], state) then
            -- Wish couldn't be granted
            break
        else
            -- Wish could be granted soon, just wait a little bit
            vars.state_notification:wait(deadline - fiber.time())
        end
    end

    return vars.state
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table clusterwide_config_new
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(clusterwide_config, _)
    checks('ClusterwideConfig', 'nil')
    assert(clusterwide_config.locked)

    local conf_new = clusterwide_config:get_readonly()
    local conf_old
    if vars.clusterwide_config then
        conf_old = vars.clusterwide_config:get_readonly()
    end
    if conf_old == nil then
        conf_old = {}
    end

    local ok, err = ddl_manager.validate_config(conf_new, conf_old)
    if not ok then
        return nil, err
    end

    return roles.validate_config(conf_new, conf_old)
end


--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(clusterwide_config)
    checks('ClusterwideConfig')
    assert(clusterwide_config.locked)
    assert(
        vars.state == 'BoxConfigured'
        or vars.state == 'RolesConfigured',
        'Unexpected state ' .. vars.state
    )

    vars.clusterwide_config = clusterwide_config

    if vars.state == 'BoxConfigured' then
        set_state('ConnectingFullmesh')
    end

    local _, err = BoxError:pcall(box.cfg, {
        replication = topology.get_fullmesh_replication(
            clusterwide_config:get_readonly('topology'), vars.replicaset_uuid
        ),
    })
    if err ~= nil then
        set_state('OperationError', err)
        return nil, err
    elseif box.info.status == 'orphan' then
        local err = BoxError:new(
            'Replication setup failed, instance in orphan mode'
        )
        set_state('OperationError', err)
        return nil, err
    else
        box.cfg({replication_connect_quorum = 0})
    end

    set_state('ConfiguringRoles')
    failover.cfg(clusterwide_config)

    local ok, err = ddl_manager.apply_config(
        clusterwide_config:get_readonly(),
        {is_master = failover.is_leader()}
    )
    if not ok then
        set_state('OperationError', err)
        return nil, err
    end

    local ok, err = roles.apply_config(clusterwide_config:get_readonly())
    if not ok then
        set_state('OperationError', err)
        return nil, err
    end

    set_state('RolesConfigured')
    return true
end


local function boot_instance(clusterwide_config)
    checks('ClusterwideConfig')
    assert(clusterwide_config.locked)
    assert(
        vars.state == 'Unconfigured' -- bootstraping from scratch
        or vars.state == 'ConfigLoaded', -- bootstraping from snapshot
        'Unexpected state ' .. vars.state
    )

    local topology_cfg = clusterwide_config:get_readonly('topology') or {}
    for _, server in pairs(topology_cfg.servers or {}) do
        if server ~= 'expelled' then
            membership.add_member(server.uri)
        end
    end

    local box_opts = table.deepcopy(vars.box_opts)
    -- TODO: https://github.com/tarantool/cartridge/issues/189
    box_opts.wal_dir = vars.workdir
    box_opts.memtx_dir = vars.workdir
    box_opts.vinyl_dir = vars.workdir
    -- Don't start listening until bootstrap/recovery finishes
    -- and prevent overriding box_opts.listen
    box_opts.listen = box.NULL
    -- By default all instances start in read-only mode
    if box_opts.read_only == nil then
        box_opts.read_only = true
    end

    -- The instance should know his uuids.
    local snapshots = fio.glob(fio.pathjoin(vars.workdir, '*.snap'))
    local advertise_uri = membership.myself().uri
    local instance_uuid
    local replicaset_uuid
    if next(snapshots) == nil then
        -- When snapshots are absent the only way to do it
        -- is to find myself by uri.
        instance_uuid = topology.find_server_by_uri(topology_cfg, advertise_uri)

        if instance_uuid == nil then
            local err = BootError:new(
                "Couldn't find server %s in clusterwide config," ..
                " bootstrap impossible",
                advertise_uri
            )
            set_state('InitError', err)
            return nil, err
        end

        local server = topology_cfg.servers[instance_uuid]
        replicaset_uuid = server.replicaset_uuid
    end

    -- There could be three options:
    if vars.state == 'ConfigLoaded' and next(snapshots) ~= nil then
        -- Instance is being recovered after restart
        set_state('RecoveringSnapshot')
        box_opts.instance_uuid = nil
        box_opts.replicaset_uuid = nil
        box_opts.replication = nil

    elseif vars.state == 'ConfigLoaded' and next(snapshots) == nil then
        -- Instance is being recovered after snapshot removal (rejoin)
        log.warn(
            "Snapshot not found in %s, can't recover." ..
            " Did previous bootstrap attempt fail?",
            vars.workdir
        )
        log.warn("Will try to rebootsrap, but it may fail again.")

        set_state('BootstrappingBox')
        box_opts.instance_uuid = assert(instance_uuid)
        box_opts.replicaset_uuid = assert(replicaset_uuid)
        box_opts.replication_connect_quorum = 1
        box_opts.replication = topology.get_fullmesh_replication(
            topology_cfg, box_opts.replicaset_uuid
        )
        -- Workaround for https://github.com/tarantool/tarantool/issues/3760
        -- which wasn't cherry-picked to tarantool 1.10 yet.
        -- Due to the bug box_opts.replication_connect_quorum was ignored
        -- and box.cfg used to hang
        table.remove(
            box_opts.replication,
            utils.table_find(
                box_opts.replication,
                pool.format_uri(advertise_uri)
            )
        )
        if #box_opts.replication == 0 then
            box_opts.read_only = false
        end

    elseif vars.state == 'Unconfigured' then
        -- Instance is being bootstrapped (neither snapshot nor config
        -- don't exist yet)
        set_state('BootstrappingBox')

        box_opts.instance_uuid = instance_uuid
        box_opts.replicaset_uuid = replicaset_uuid

        local leaders_order = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
        local leader_uuid = leaders_order[1]
        local leader = topology_cfg.servers[leader_uuid]

        -- Set up 'star' replication for the bootstrap
        if instance_uuid == leader_uuid then
            box_opts.replication = nil
            box_opts.read_only = false
            -- leader should be bootstrapped with quorum = 0, otherwise
            -- there'll be a race during parallel bootstrap. Leader will
            -- enter orphan mode (temporarily, until it connects to the
            -- replica) and replica would fail to join because leader is
            -- readonly.
            box_opts.replication_connect_quorum = 0
        else
            box_opts.replication = {pool.format_uri(leader.uri)}
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

        local _, err = BoxError:pcall(
            box.schema.user.grant,
            username, 'replication',
            nil, nil, {if_not_exists = true}
        )
        if err ~= nil then
            log.error('%s', err)
        end
    end

    do
        log.info('Setting password for user %q ...', username)
        -- To be sure netbox is operable, password should always be
        -- equal to the cluster_cookie.
        -- Function `passwd` is safe to be called on multiple replicas,
        -- it never cause replication conflict

        local read_only = box.cfg.read_only
        box.cfg({read_only = false})

        BoxError:pcall(
            box.schema.user.passwd,
            username, password
        )

        box.cfg({read_only = read_only})
    end

    -- Box is ready, start listening full-featured iproto protocol
    remote_control.stop()
    local _, err = BoxError:pcall(
        box.cfg, {listen = vars.binary_port}
    )

    if err ~= nil then
        set_state('BootError', err)
        return nil, err
    else
        remote_control.drop_connections()
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
    return apply_config(clusterwide_config)
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

    local ok, err = remote_control.bind('0.0.0.0', vars.binary_port)
    if not ok then
        set_state('InitError', err)
        return nil, err
    else
        log.info('Remote control bound to 0.0.0.0:%d', vars.binary_port)
    end

    local config_filename = fio.pathjoin(vars.workdir, 'config')
    if not utils.file_exists(config_filename) then
        config_filename = config_filename .. '.yml'
    end
    if not utils.file_exists(config_filename) then
        remote_control.accept({
            username = cluster_cookie.username(),
            password = cluster_cookie.cookie(),
        })
        log.info('Remote control ready to accept connections')

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
        local clusterwide_config, err = ClusterwideConfig.load(config_filename)
        if clusterwide_config == nil then
            set_state('InitError', err)
            return true
        end

        -- TODO validate vshard groups

        vars.clusterwide_config = clusterwide_config:lock()
        local ok, err = validate_config(clusterwide_config)
        if not ok then
            set_state('InitError', err)
            return true
        end

        set_state('ConfigLoaded')
        fiber.new(boot_instance, clusterwide_config)
    end

    return true
end

local function get_active_config()
    return vars.clusterwide_config
end

--- Get a read-only view on the clusterwide configuration.
--
-- Returns either `conf[section_name]` or entire `conf`.
-- Any attempt to modify the section or its children
-- will raise an error.
-- @function get_readonly
-- @tparam[opt] string section_name
-- @treturn table
local function get_readonly(section)
    checks('?string')
    if vars.clusterwide_config == nil then
        return nil
    end
    return vars.clusterwide_config:get_readonly(section)
end

--- Get a read-write deep copy of the clusterwide configuration.
--
-- Returns either `conf[section_name]` or entire `conf`.
-- Changing it has no effect
-- unless it's used to patch clusterwide configuration.
-- @function get_deepcopy
-- @tparam[opt] string section_name
-- @treturn table
local function get_deepcopy(section)
    checks('?string')
    if vars.clusterwide_config == nil then
        return nil
    end
    return vars.clusterwide_config:get_deepcopy(section)
end

return {
    init = init,
    boot_instance = boot_instance,
    apply_config = apply_config,
    validate_config = validate_config,

    get_active_config = get_active_config,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    set_state = set_state,
    wish_state = wish_state,
    get_state = function() return vars.state, vars.error end,
    get_workdir = function() return vars.workdir end,
    get_instance_uuid = function() return vars.instance_uuid end,
    get_replicaset_uuid = function() return vars.replicaset_uuid end,
}
