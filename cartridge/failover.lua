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
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.failover')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')

local FailoverError = errors.new_class('FailoverError')
local ApplyConfigError = errors.new_class('ApplyConfigError')
local NetboxConnectError = errors.new_class('NetboxConnectError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local StateProviderError = errors.new_class('StateProviderError')

vars:new('membership_notification', membership.subscribe())
vars:new('clusterwide_config')
vars:new('failover_fiber')
vars:new('kingdom_conn')
vars:new('cache', {
    active_leaders = {--[[ [replicaset_uuid] = leader_uuid ]]},
    is_leader = false,
    is_rw = false,
})
vars:new('options', {
    LONGPOLL_TIMEOUT = 30,
    NETBOX_CALL_TIMEOUT = 1,
})

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
local function _get_appointments_stateful_mode(conn, timeout)
    checks('table', 'number')
    local appointments, err = errors.netbox_call(
        -- Server will answer in `timeout` seconds (maybe)
        conn, 'longpoll', {timeout},
        -- But if it doesn't, we give him another spare second.
        {timeout = timeout + vars.options.NETBOX_CALL_TIMEOUT}
    )

    if appointments == nil then
        return nil, err
    end

    return appointments
end

--- Accept new appointments.
--
-- Get appointments wherever they come from and put them into cache.
--
-- @function accept_appointments
-- @local
-- @tparam {[string]=string} replicaset_uuid to leader_uuid map
-- @treturn boolean Whether leadership map has changed
local function accept_appointments(appointments)
    checks('table')
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    local replicasets = assert(topology_cfg.replicasets)

    local old_leaders = table.copy(vars.cache.active_leaders)

    -- Merge new appointments into cache
    for replicaset_uuid, leader_uuid in pairs(appointments) do
        vars.cache.active_leaders[replicaset_uuid] = leader_uuid
    end

    -- Remove replicasets that aren't listed in topology
    for replicaset_uuid, _ in pairs(vars.cache.active_leaders) do
        if replicasets[replicaset_uuid] == nil then
            vars.cache.active_leaders[replicaset_uuid] = nil
        end
    end

    -- Constitute oneself
    if vars.cache.active_leaders[box.info.cluster.uuid] == box.info.uuid then
        vars.cache.is_leader = true
        vars.cache.is_rw = true
    else
        vars.cache.is_leader = false
        vars.cache.is_rw = replicasets[box.info.cluster.uuid].all_rw
    end

    return not utils.deepcmp(old_leaders, vars.cache.active_leaders)
end

local function apply_config(mod)
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

--- Repeatedly fetch new appointments and reconfigure roles.
--
-- @function failover_loop
-- @local
local function failover_loop(args)
    checks({
        get_appointments = 'function',
    })
    local confapplier = require('cartridge.confapplier')
    local all_roles = require('cartridge.roles').get_all_roles()

    ::start_over::

    while pcall(fiber.testcancel) do
        local appointments, err = FailoverError:pcall(args.get_appointments)
        if appointments == nil then
            log.warn('%s', err.err)
            goto start_over
        end

        if not accept_appointments(appointments) then
            -- nothing changed
            goto start_over
        end

        -- The event may arrive during two-phase commit is in progress.
        -- We should wait for the appropriate state.
        local state = confapplier.wish_state('RolesConfigured', math.huge)
        if state ~= 'RolesConfigured' then
            log.info('Skipping failover step - state is %s', state)
            goto start_over
        end

        log.info('Failover triggered')
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
end

------------------------------------------------------------------------

--- Initialize the failover module.
-- @function cfg
-- @local
local function cfg(clusterwide_config)
    checks('ClusterwideConfig')

    if vars.kingdom_conn then
        vars.kingdom_conn:close()
        vars.kingdom_conn = nil
    end

    if vars.failover_fiber ~= nil then
        if vars.failover_fiber:status() ~= 'dead' then
            vars.failover_fiber:cancel()
        end
        vars.failover_fiber = nil
    end

    vars.clusterwide_config = clusterwide_config
    local topology_cfg = clusterwide_config:get_readonly('topology')
    local failover_cfg = topology.get_failover_params(topology_cfg)
    local first_appointments

    if failover_cfg.mode == 'disabled' then
        log.info('Failover disabled')
        first_appointments = _get_appointments_disabled_mode(topology_cfg)

    elseif failover_cfg.mode == 'eventual' then
        log.info('Eventual failover enabled')
        first_appointments = _get_appointments_eventual_mode(topology_cfg)

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                vars.membership_notification:wait()
                return _get_appointments_eventual_mode(topology_cfg)
            end,
        })
        vars.failover_fiber:name('cartridge.eventual-failover')

    elseif failover_cfg.mode == 'stateful' and failover_cfg.state_provider == 'tarantool' then
        local params = assert(failover_cfg.tarantool_params)
        local conn, err = NetboxConnectError:pcall(
            netbox.connect, assert(params.uri), {
            wait_connected = false,
            reconnect_after = 1.0,
            user = 'client',
            password = params.password,
        })

        if conn == nil then
            log.warn('Stateful failover not enabled: %s', err)
            return nil, err
        else
            log.info(
                'Stateful failover enabled with external storage at %s',
                params.uri
            )
        end

        vars.kingdom_conn = conn

        -- WARNING: network yields
        first_appointments = _get_appointments_stateful_mode(conn, 0)
        if first_appointments == nil then
            first_appointments = {}
        end

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                return _get_appointments_stateful_mode(conn,
                    vars.options.LONGPOLL_TIMEOUT
                )
            end,
        })
        vars.failover_fiber:name('cartridge.stateful-failover')
    else
        error('Unknown failover mode')
    end

    accept_appointments(first_appointments)
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

--- Get current stateful failover coordinator
-- @function get_coordinator
-- @treturn[1] table coordinator
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_coordinator()
    if vars.kingdom_conn == nil
    or not vars.kingdom_conn:is_connected()
    then
        return nil, StateProviderError:new('State provider unavailable')
    end

    return errors.netbox_call(
        vars.kingdom_conn, 'get_coordinator',
        {}, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
    )
end

return {
    cfg = cfg,
    get_active_leaders = get_active_leaders,
    is_leader = is_leader,
    is_rw = is_rw,
    get_coordinator = get_coordinator,
}
