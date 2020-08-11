--- Gather information regarding instances leadership.
--
-- Failover can operate in two modes:
--
-- * In `disabled` mode the leader is the first server configured in
--   `topology.replicasets[].master` array.
-- * In `eventual` mode the leader isn't elected consistently.
--   Instead, every instance in cluster thinks the leader is the
--   first **healthy** server in replicaset, while instance health is
--   determined according to membership status (the SWIM protocol).
-- * In `stateful` mode leaders appointments are polled from the
--   external storage. (**Added** in v2.0.2-2)
--
-- This module behavior depends on the instance state.
--
-- From the very beginning it reports `is_rw() == false`,
-- `is_leader() == false`, `get_active_leaders() == {}`.
--
-- The module is configured when the instance enters `ConfiguringRoles`
-- state for the first time. From that moment it reports actual values
-- according to the mode set in clusterwide config.
--
-- (**Added** in v1.2.0-17)
--
-- @module cartridge.failover
-- @local

local log = require('log')
local json = require('json')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.failover')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')
local stateboard_client = require('cartridge.stateboard-client')
local etcd2_client = require('cartridge.etcd2-client')

local FailoverError = errors.new_class('FailoverError')
local SwitchoverError = errors.new_class('SwitchoverError')
local ApplyConfigError = errors.new_class('ApplyConfigError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local StateProviderError = errors.new_class('StateProviderError')

vars:new('membership_notification', membership.subscribe())
vars:new('consistency_needed', false)
vars:new('clusterwide_config')
vars:new('failover_fiber')
vars:new('failover_err')
vars:new('schedule', {})
vars:new('client')
vars:new('cache', {
    active_leaders = {--[[ [replicaset_uuid] = leader_uuid ]]},
    is_vclockkeeper = false,
    is_leader = false,
    is_rw = false,
})
vars:new('options', {
    WAITLSN_PAUSE = 0.2,
    WAITLSN_TIMEOUT = 3,
    LONGPOLL_TIMEOUT = 30,
    NETBOX_CALL_TIMEOUT = 1,
})

function _G.__cartridge_failover_get_lsn(timeout)
    box.ctl.wait_ro(timeout)
    return {
        id  = box.info.id,
        lsn = box.info.lsn,
    }
end

function _G.__cartridge_failover_wait_rw(timeout)
    return errors.pcall('WaitRwError', box.ctl.wait_rw, timeout)
end

--- Generate appointments according to clusterwide configuration.
-- Used in 'disabled' failover mode.
-- @function _get_appointments_disabled_mode
-- @local
local function _get_appointments_disabled_mode(topology_cfg)
    checks('table')
    local replicasets = assert(topology_cfg.replicasets)

    local appointments = {}

    for replicaset_uuid, _ in pairs(replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
        appointments[replicaset_uuid] = leaders[1]
    end

    return appointments
end

--- Generate appointments according to membership status.
-- Used in 'eventual' failover mode.
-- @function _get_appointments_eventual_mode
-- @local
local function _get_appointments_eventual_mode(topology_cfg)
    checks('table')
    local replicasets = assert(topology_cfg.replicasets)

    local appointments = {}

    for replicaset_uuid, _ in pairs(replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )

        for _, instance_uuid in ipairs(leaders) do
            local server = topology_cfg.servers[instance_uuid]
            local member = membership.get_member(server.uri)

            if member ~= nil
            and (member.status == 'alive' or member.status == 'suspect')
            and member.payload.uuid == instance_uuid
            and (
                member.payload.state == 'ConfiguringRoles' or
                member.payload.state == 'RolesConfigured'
            ) then
                appointments[replicaset_uuid] = instance_uuid
                break
            end
        end

        if appointments[replicaset_uuid] == nil then
            appointments[replicaset_uuid] = leaders[1]
        end
    end

    return appointments
end

--- Get appointments from external storage.
-- Used in 'stateful' failover mode.
-- @function _get_appointments_stateful_mode
-- @local
local function _get_appointments_stateful_mode(client, timeout)
    checks('stateboard_client|etcd2_client', 'number')
    return client:longpoll(timeout)
end

--- Accept new appointments.
--
-- Get appointments wherever they come from and put them into cache.
-- Cached active_leaders table is never modified, but overriden by it's
-- modified copy (if necessary).
--
-- @function accept_appointments
-- @local
-- @tparam {[string]=string} replicaset_uuid to leader_uuid map
-- @treturn boolean Whether leadership map has changed
local function accept_appointments(appointments)
    checks('table')
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    local replicasets = assert(topology_cfg.replicasets)

    local active_leaders = table.copy(vars.cache.active_leaders)

    -- Merge new appointments
    for replicaset_uuid, leader_uuid in pairs(appointments) do
        active_leaders[replicaset_uuid] = leader_uuid
    end

    -- Remove replicasets that aren't listed in topology
    for replicaset_uuid, _ in pairs(active_leaders) do
        if replicasets[replicaset_uuid] == nil then
            active_leaders[replicaset_uuid] = nil
        end
    end

    if utils.deepcmp(vars.cache.active_leaders, active_leaders) then
        return false
    end

    vars.cache.active_leaders = active_leaders
    return true
end

local function apply_config(mod)
    checks('?table')
    if mod == nil then
        return true
    end

    if type(mod.apply_config) ~= 'function' then
        return true
    end

    local conf = vars.clusterwide_config:get_readonly()
    if type(mod.validate_config) == 'function' then
        local ok, err = ValidateConfigError:pcall(
            mod.validate_config, conf, conf
        )
        if not ok then
            err = err or ValidateConfigError:new(
                'validate_config() returned %s', ok
            )
            return nil, err
        end
    end

    return ApplyConfigError:pcall(
        mod.apply_config, conf, {is_master = vars.cache.is_leader}
    )
end

local function constitute_oneself(active_leaders, opts)
    checks('table', {
        timeout = 'number',
    })

    local confapplier = require('cartridge.confapplier')
    local instance_uuid = confapplier.get_instance_uuid()
    local replicaset_uuid = confapplier.get_replicaset_uuid()

    local topology_cfg = vars.clusterwide_config:get_readonly('topology')

    if active_leaders[replicaset_uuid] ~= instance_uuid then
        -- I'm not a leader
        vars.cache.is_vclockkeeper = false
        vars.cache.is_leader = false
        vars.cache.is_rw = topology_cfg.replicasets[replicaset_uuid].all_rw
        return true
    end

    -- Get ready to become a leader
    if not vars.consistency_needed then
        vars.cache.is_vclockkeeper = false
        vars.cache.is_leader = true
        vars.cache.is_rw = true
        return true
    elseif vars.cache.is_vclockkeeper then
        -- I'm already a vclockkeeper
        return true
    end

    local deadline = fiber.clock() + opts.timeout

    -- Go to the external state provider
    local session = assert(vars.client):get_session()
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    -- Query current vclockkeeper
    -- WARNING: implicit yield
    local vclockkeeper, err = session:get_vclockkeeper(replicaset_uuid)
    fiber.testcancel()
    if err ~= nil then
        return nil, SwitchoverError:new(err)
    end

    if vclockkeeper == nil then
        -- It's absent, no need to wait anyone
        goto set_vclockkeeper
    elseif vclockkeeper.instance_uuid == instance_uuid then
        -- It's me already, but vclock still should be persisted
        goto set_vclockkeeper
    end

    do
        -- Go to the vclockkeeper and query its LSN
        local vclockkeeper_uuid = vclockkeeper.instance_uuid
        local vclockkeeper_srv = topology_cfg.servers[vclockkeeper_uuid]
        if vclockkeeper_srv == nil then
            return nil, SwitchoverError:new('Alien vclockkeeper %q',
                vclockkeeper.instance_uuid
            )
        end

        local vclockkeeper_uri = vclockkeeper_srv.uri

        local timeout = deadline - fiber.clock()
        -- WARNING: implicit yield
        local vclockkeeper_info, err = errors.netbox_call(
            pool.connect(vclockkeeper_uri, {wait_connected = false}),
            '__cartridge_failover_get_lsn', {timeout},
            {timeout = timeout + vars.options.NETBOX_CALL_TIMEOUT}
        )
        fiber.testcancel()

        if vclockkeeper_info == nil then
            return nil, SwitchoverError:new(err)
        end

        -- Wait async replication to arrive
        -- WARNING: implicit yield
        local timeout = deadline - fiber.clock()
        local ok = utils.wait_lsn(
            vclockkeeper_info.id,
            vclockkeeper_info.lsn,
            vars.options.WAITLSN_PAUSE,
            timeout
        )
        fiber.testcancel()
        if not ok then
            return nil, SwitchoverError:new(
                "Can't catch up with the vclockkeeper"
            )
        end
    end

    -- The last one thing: persist our vclock
    ::set_vclockkeeper::
    local vclock = box.info.vclock

    -- WARNING: implicit yield
    local ok, err = session:set_vclockkeeper(
        replicaset_uuid, instance_uuid, vclock
    )
    fiber.testcancel()

    if ok == nil then
        return nil, SwitchoverError:new(err)
    end

    -- Hooray, instance is a legal vclockkeeper now.
    vars.cache.is_vclockkeeper = true
    vars.cache.is_leader = true
    vars.cache.is_rw = true

    log.info('Vclock persisted: %s',
        json.encode(setmetatable(vclock, {_serialize = 'sequence'}))
    )

    return true
end

local function reconfigure_all(active_leaders)
    local confapplier = require('cartridge.confapplier')
    local all_roles = require('cartridge.roles').get_all_roles()

::start_over::

    local t1 = fiber.clock()
    -- WARNING: implicit yield
    local ok, _ = constitute_oneself(active_leaders, {
        timeout = vars.options.WAITLSN_TIMEOUT,
    })
    fiber.testcancel()
    local t2 = fiber.clock()

    if not ok then
        fiber.sleep(t1 + vars.options.WAITLSN_TIMEOUT - t2)
        goto start_over
    end

    -- WARNING: implicit yield
    -- The event may arrive while two-phase commit is in progress.
    -- We should wait for the appropriate state.
    local state = confapplier.wish_state('RolesConfigured', math.huge)
    fiber.testcancel()

    if state ~= 'RolesConfigured' then
        log.info('Skipping failover step - state is %s', state)
        return
    end

    fiber.self().storage.is_busy = true
    confapplier.set_state('ConfiguringRoles')

    local ok, err = FailoverError:pcall(function()
        box.cfg({
            read_only = not vars.cache.is_rw,
        })

        for _, role_name in ipairs(all_roles) do
            local mod = service_registry.get(role_name)
            local _, err = apply_config(mod)
            if err then
                log.error('Role %q failover failed', mod.role_name)
                log.error('%s', err)
            end
        end

        return true
    end)

    if ok then
        log.info('Failover step finished')
    else
        log.warn('Failover step failed: %s', err)
    end
    confapplier.set_state('RolesConfigured')
end

--- Repeatedly fetch new appointments and reconfigure roles.
--
-- @function failover_loop
-- @local
local function failover_loop(args)
    checks({
        get_appointments = 'function',
    })

    while true do
        -- WARNING: implicit yield
        local appointments, err = FailoverError:pcall(args.get_appointments)
        fiber.testcancel()

        local csw1 = fiber.info()[fiber.id()].csw

        if appointments == nil then
            log.warn('%s', err.err)
            vars.failover_err = FailoverError:new(
                "Error fetching appointments: %s", err.err
            )
            goto continue
        end

        vars.failover_err = nil

        if not accept_appointments(appointments) then
            -- nothing changed
            goto continue
        end

        -- Cancel all pending tasks
        for id, task in pairs(vars.schedule) do
            if task:status() == 'dead' then
                vars.schedule[id] = nil
            elseif not task.storage.is_busy then
                vars.schedule[id] = nil
                task:cancel()
            -- else
                -- preserve busy tasks
            end
        end

        -- Schedule new task
        do
            local task = fiber.new(reconfigure_all, vars.cache.active_leaders)
            local id = task:id()
            task:name('cartridge.failover.task')
            vars.schedule[id] = task
            log.info('Failover triggered, reapply scheduled (fiber %d)', id)
        end

        ::continue::
        local csw2 = fiber.info()[fiber.id()].csw
        assert(csw1 == csw2, 'Unexpected yield')
    end
end

------------------------------------------------------------------------

--- Initialize the failover module.
-- @function cfg
-- @local
local function cfg(clusterwide_config)
    checks('ClusterwideConfig')

    if vars.client then
        vars.client:drop_session()
        vars.client = nil
    end

    -- Cancel all pending tasks
    for id, task in pairs(vars.schedule) do
        if task:status() == 'dead' then
            vars.schedule[id] = nil
        else
            assert(not task.storage.is_busy)
            vars.schedule[id] = nil
            task:cancel()
        end
    end

    if vars.failover_fiber ~= nil then
        if vars.failover_fiber:status() ~= 'dead' then
            vars.failover_fiber:cancel()
        end
        vars.failover_fiber = nil
    end

    vars.failover_err = nil

    vars.clusterwide_config = clusterwide_config
    local topology_cfg = clusterwide_config:get_readonly('topology')
    local failover_cfg = topology.get_failover_params(topology_cfg)
    local first_appointments

    if failover_cfg.mode == 'disabled' then
        log.info('Failover disabled')
        vars.consistency_needed = false
        first_appointments = _get_appointments_disabled_mode(topology_cfg)

    elseif failover_cfg.mode == 'eventual' then
        log.info('Eventual failover enabled')
        vars.consistency_needed = false
        first_appointments = _get_appointments_eventual_mode(topology_cfg)

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                vars.membership_notification:wait()
                return _get_appointments_eventual_mode(topology_cfg)
            end,
        })
        vars.failover_fiber:name('cartridge.eventual-failover')

    elseif failover_cfg.mode == 'stateful' then
        if topology_cfg.replicasets[box.info.cluster.uuid].all_rw then
            -- Replicasets with all_rw flag imply that
            -- consistent switchover isn't necessary
            vars.consistency_needed = false
        else
            vars.consistency_needed = true
        end

        if failover_cfg.state_provider == 'tarantool' then
            local params = assert(failover_cfg.tarantool_params)
            vars.client = stateboard_client.new({
                uri = assert(params.uri),
                password = params.password,
                call_timeout = vars.options.NETBOX_CALL_TIMEOUT,
            })

            log.info(
                'Stateful failover enabled with stateboard at %s',
                params.uri
            )
        elseif failover_cfg.state_provider == 'etcd2' then
            local params = assert(failover_cfg.etcd2_params)
            vars.client = etcd2_client.new({
                endpoints = params.endpoints,
                prefix = params.prefix,
                username = params.username,
                password = params.password,
                lock_delay = params.lock_delay,
                request_timeout = vars.options.NETBOX_CALL_TIMEOUT,
            })

            log.info(
                'Stateful failover enabled with etcd-v2 at %s',
                table.concat(params.endpoints, ', ')
            )
        else
            return nil, ApplyConfigError:new(
                'Unknown failover state provider %q',
                failover_cfg.state_provider
            )
        end

        -- WARNING: implicit yield
        local appointments, err = _get_appointments_stateful_mode(vars.client, 0)
        if appointments == nil then
            log.warn('Failed to get first appointments: %s', err)
            vars.failover_err = FailoverError:new(
                "Error fetching first appointments: %s", err.err
            )
            first_appointments = {}
        else
            first_appointments = appointments
        end

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                return _get_appointments_stateful_mode(vars.client,
                    vars.options.LONGPOLL_TIMEOUT
                )
            end,
        })
        vars.failover_fiber:name('cartridge.stateful-failover')
    else
        return nil, ApplyConfigError:new(
            'Unknown failover mode %q',
            failover_cfg.mode
        )
    end

    accept_appointments(first_appointments)

    local ok, err = constitute_oneself(vars.cache.active_leaders, {
        timeout = vars.options.WAITLSN_TIMEOUT
    })
    if ok == nil then
        log.warn("Error reaching consistency: %s", err)
        if next(vars.schedule) == nil then
            local task = fiber.new(reconfigure_all, vars.cache.active_leaders)
            local id = task:id()
            task:name('cartridge.failover.task')
            vars.schedule[id] = task
            log.info('Consistency not reached, another attempt scheduled (fiber %d)', id)
        end
    end

    box.cfg({
        read_only = not vars.cache.is_rw,
    })

    return true
end

--- Get map of replicaset leaders.
-- @function get_active_leaders
-- @local
-- @return {[replicaset_uuid] = instance_uuid,...}
local function get_active_leaders()
    return vars.cache.active_leaders
end

--- Check current instance leadership.
-- @function is_leader
-- @local
-- @treturn boolean true / false
local function is_leader()
    return vars.cache.is_leader
end

--- Check current instance writability.
-- @function is_rw
-- @local
-- @treturn boolean true / false
local function is_rw()
    return vars.cache.is_rw
end

--- Check if current instance has persisted his vclock.
-- @function is_vclockkeeper
-- @local
-- @treturn boolean true / false
local function is_vclockkeeper()
    return vars.cache.is_vclockkeeper
end

--- Check if current configuration implies consistent switchover.
-- @function consistency_needed
-- @local
-- @treturn boolean true / false
local function consistency_needed()
    return vars.consistency_needed
end

--- Get current stateful failover coordinator
-- @function get_coordinator
-- @treturn[1] table coordinator
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_coordinator()
    if vars.client == nil then
        return nil, StateProviderError:new("No state provider configured")
    end

    local session = vars.client.session
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    return session:get_coordinator()
end

local function get_error()
    if vars.failover_fiber ~= nil
    and vars.failover_fiber:status() == 'dead'
    then
        return FailoverError:new('Failover fiber is dead!')
    end

    return vars.failover_err
end

--- Force inconsistent leader switching.
-- Do it by resetting vclockkepers in state provider.
--
-- @function force_inconsistency
-- @local
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function force_inconsistency(leaders)
    if vars.client == nil then
        return nil, StateProviderError:new("No state provider configured")
    end

    local session = vars.client.session
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    local err
    for replicaset_uuid, instance_uuid in pairs(leaders) do
        local _ok, _err = session:set_vclockkeeper(replicaset_uuid, instance_uuid)
        if _ok == nil then
            err = _err
            log.warn(
                'Forcing inconsistency for %s failed: %s', instance_uuid,
                errors.is_error_object(_err) and _err.err or _err
            )
        end
    end

    if err ~= nil then
        return nil, err
    end

    return true
end

--- Wait when promoted instances become vclockkepers.
--
-- @function wait_consistency
-- @local
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function wait_consistency(leaders)
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    assert(topology_cfg.servers)

    local uri_list = {}
    for _, instance_uuid in pairs(leaders) do
        assert(topology_cfg.servers[instance_uuid])
        table.insert(uri_list, topology_cfg.servers[instance_uuid].uri)
    end

    local timeout = vars.options.WAITLSN_TIMEOUT
    local _, err = pool.map_call(
        '_G.__cartridge_failover_wait_rw', {timeout},
        {
            uri_list = uri_list,
            timeout = timeout + vars.options.NETBOX_CALL_TIMEOUT,
        }
    )

    if err ~= nil then
        log.warn("Waiting consistent switchover didn't succeed: %s", err)
        local _, err = next(err.suberrors)
        return nil, err
    end

    return true
end

return {
    cfg = cfg,
    get_active_leaders = get_active_leaders,
    get_coordinator = get_coordinator,
    get_error = get_error,

    consistency_needed = consistency_needed,
    is_vclockkeeper = is_vclockkeeper,
    is_leader = is_leader,
    is_rw = is_rw,

    force_inconsistency = force_inconsistency,
    wait_consistency = wait_consistency,
}
