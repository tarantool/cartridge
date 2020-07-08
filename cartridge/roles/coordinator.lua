local log = require('log')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local stateboard_client = require('cartridge.stateboard-client')
local etcd2_client = require('cartridge.etcd2-client')

local AppointmentError = errors.new_class('AppointmentError')
local CoordinatorError = errors.new_class('CoordinatorError')

vars:new('membership_notification', membership.subscribe())
vars:new('connect_fiber', nil)
vars:new('topology_cfg', nil)
vars:new('client', nil)
vars:new('options', {
    RECONNECT_PERIOD = 5,
    IMMUNITY_TIMEOUT = 15,
    NETBOX_CALL_TIMEOUT = 1,
})

-- The healthcheck function is put into vars for easier
-- monkeypatching and further extending.
vars:new('healthcheck', function(members, instance_uuid)
    checks('table', 'string')
    assert(vars.topology_cfg ~= nil)
    assert(vars.topology_cfg.servers ~= nil)

    local server = vars.topology_cfg.servers[instance_uuid]
    if server == nil or not topology.not_disabled(instance_uuid, server) then
        return false
    end
    local member = members[server.uri]

    if member ~= nil
    and (member.status == 'alive' or member.status == 'suspect')
    and (member.payload.uuid == instance_uuid)
    then
        return true
    end

    return false
end)

local function pack_decision(leader_uuid)
    checks('string')
    return {
        leader = leader_uuid,
        immunity = fiber.clock() + vars.options.IMMUNITY_TIMEOUT,
        -- decision is immune if fiber.clock() < immunity
    }
end

local function make_decision(ctx, replicaset_uuid)
    checks({members = 'table', decisions = 'table'}, 'string')

    local current_decision = ctx.decisions[replicaset_uuid]
    if current_decision ~= nil then
        if fiber.clock() < current_decision.immunity
        or vars.healthcheck(ctx.members, current_decision.leader)
        then
            return nil
        end
    end

    local candidates = topology.get_leaders_order(
        vars.topology_cfg, replicaset_uuid
    )

    if current_decision == nil then
        -- This is a case when new replicaset is created.
        -- First appointment is always made according to `topology_cfg`
        -- without regard to the healthcheck
        local decision = pack_decision(candidates[1])
        ctx.decisions[replicaset_uuid] = decision
        return decision
    end

    for _, instance_uuid in ipairs(candidates) do
        if vars.healthcheck(ctx.members, instance_uuid) then
            local decision = pack_decision(instance_uuid)
            ctx.decisions[replicaset_uuid] = decision
            return decision
        end
    end
end

local function control_loop(session)
    checks('stateboard_session|etcd2_session')
    local ctx = assert(session.ctx)

    while true do
        ctx.members = membership.members()

        local updates = {}

        for replicaset_uuid, _ in pairs(vars.topology_cfg.replicasets) do
            local decision = make_decision(ctx, replicaset_uuid)
            if decision ~= nil then
                table.insert(updates, {replicaset_uuid, decision.leader})
                log.info('Appoint new leader %s -> %s (%q)',
                    replicaset_uuid, decision.leader,
                    vars.topology_cfg.servers[decision.leader].uri
                )
            end
        end

        local now = fiber.clock()
        if next(updates) ~= nil then
            for _, update in ipairs(updates) do
                session:set_vclockkeeper(update[1], update[2])
            end

            local ok, err = session:set_leaders(updates)
            if ok == nil then
                -- don't log an error in case the fiber was cancelled
                fiber.testcancel()

                log.error('%s', err)
                break
            end
        end

        local next_moment = math.huge
        for _, decision in pairs(ctx.decisions) do
            if (decision.immunity >= now)
            and (decision.immunity < next_moment)
            then
                next_moment = decision.immunity
            end
        end

        assert(next_moment >= now)
        vars.membership_notification:wait(next_moment - now)
        fiber.testcancel()
    end
end

local function take_control(client)
    checks('stateboard_client|etcd2_client')

    local lock_args = {
        uuid = confapplier.get_instance_uuid(),
        uri = confapplier.get_advertise_uri(),
    }

    local session = client:get_session()
    assert(not session:is_locked())
    assert(session.ctx == nil)

    local lock_delay, err = session:get_lock_delay()
    if lock_delay == nil then
        return nil, err
    end

    while true do
        local ok, err = session:acquire_lock(lock_args)
        if ok == nil then
            return nil, err
        end

        if not ok then
            fiber.sleep(lock_delay/2)
        else
            break
        end
    end

    local leaders, err = session:get_leaders()
    if leaders == nil then
        return nil, err
    end

    local ctx = {
        members = nil,
        decisions = {}
    }
    for replicaset_uuid, leader_uuid in pairs(leaders) do
        ctx.decisions[replicaset_uuid] = pack_decision(leader_uuid)
    end
    session.ctx = ctx

    log.info('Lock acquired')
    --------------------------------------------------------------------
    local control_fiber = fiber.new(control_loop, session)
    control_fiber:name('failover-coordinate')

    -- Warning: fragile code.
    -- The goal: perform garbage collection when the fiber is cancelled
    repeat
        if not pcall(fiber.sleep, lock_delay/2) then
            break
        end

        if fiber.status(control_fiber) == 'dead'
        or not session:acquire_lock(lock_args)
        then
            break
        end
    until not pcall(fiber.testcancel)

    session:drop()
    pcall(fiber.cancel, control_fiber)

    log.info('Lock released')
    return true
end

local function take_control_loop(client)
    checks('stateboard_client|etcd2_client')

    while true do
        local t1 = fiber.clock()
        local ok, err = CoordinatorError:pcall(take_control, client)
        fiber.testcancel()
        local t2 = fiber.clock()

        if ok == nil then
            log.error('%s', type(err) == 'table' and err.err or err)
        end

        if ok ~= true then
            fiber.sleep(t1 + vars.options.RECONNECT_PERIOD - t2)
        end
    end
end

local function stop()
    if vars.connect_fiber ~= nil then
        pcall(fiber.cancel, vars.connect_fiber)
        vars.connect_fiber = nil
    end

    if vars.client ~= nil then
        vars.client:drop_session()
        vars.client = nil
    end
end

local function apply_config(conf, _)
    vars.topology_cfg = conf.topology
    local failover_cfg = topology.get_failover_params(conf.topology)

    if failover_cfg.mode ~= 'stateful' then
        stop()
        return true
    end

    if failover_cfg.state_provider == 'tarantool' then
        local params = assert(failover_cfg.tarantool_params)
        local client_cfg = {
            uri = params.uri,
            password = params.password,
            call_timeout = vars.options.NETBOX_CALL_TIMEOUT,
        }

        if vars.client == nil
        or vars.client.state_provider ~= 'tarantool'
        or not utils.deepcmp(vars.client.cfg, client_cfg)
        then
            stop()
            vars.client = stateboard_client.new(client_cfg)

            log.info(
                'Starting failover coordinator' ..
                ' with external storage (stateboard) at %s',
                client_cfg.uri
            )
        end
    elseif failover_cfg.state_provider == 'etcd2' then
        local params = assert(failover_cfg.etcd2_params)
        local client_cfg = {
            endpoints = params.endpoints,
            prefix = params.prefix,
            username = params.username,
            password = params.password,
            lock_delay = params.lock_delay,
            request_timeout = vars.options.NETBOX_CALL_TIMEOUT,
        }

        if vars.client == nil
        or vars.client.state_provider ~= 'etcd2'
        or not utils.deepcmp(vars.client.cfg, client_cfg)
        then
            stop()
            vars.client = etcd2_client.new(client_cfg)
        end
    else
        local err = string.format(
            'assertion failed! unknown state_provider %s',
            failover_cfg.state_provider
        )
        error(err)
    end

    if vars.connect_fiber == nil
    or vars.connect_fiber:status() == 'dead'
    then
        if vars.connect_fiber ~= nil then
            log.warn('Failover coordinator fiber was dead, restarting')
        end
        vars.connect_fiber = fiber.new(take_control_loop, vars.client)
        vars.connect_fiber:name('failover-take-control')
    end

    vars.membership_notification:broadcast()
    return true
end

--- Manually set leaders.
--
-- @function appoint_leaders
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function appoint_leaders(leaders)
    checks('table')

    local servers = vars.topology_cfg.servers
    local replicasets = vars.topology_cfg.replicasets

    for k, v in pairs(leaders) do
        if type(k) ~= 'string' or type(v) ~= 'string' then
            error('bad argument #1 to appoint_leaders' ..
                ' (keys and values must be strings)', 2
            )
        end

        local replicaset = replicasets[k]
        if replicaset == nil then
            return nil, AppointmentError:new(
                "Replicaset %q doesn't exist", k
            )
        end

        local server = servers[v]
        if server == nil then
            return nil, AppointmentError:new(
                "Server %q doesn't exist", v
            )
        end

        if server.replicaset_uuid ~= k then
            return nil, AppointmentError:new(
                "Server %q doesn't belong to replicaset %q", v, k
            )
        end
    end

    if vars.client == nil then
        return nil, AppointmentError:new("No state provider configured")
    end

    local session = vars.client.session
    if session == nil
    or session.ctx == nil
    or not session:is_locked()
    then
        return nil, AppointmentError:new("No active coordinator session")
    end

    local updates = {}
    for replicaset_uuid, leader_uuid in pairs(leaders) do
        local decision = pack_decision(leader_uuid)
        table.insert(updates, {replicaset_uuid, decision.leader})
        session.ctx.decisions[replicaset_uuid] = decision
    end

    local ok, err = session:set_leaders(updates)
    vars.membership_notification:broadcast()
    if ok == nil then
        session:drop()
        return nil, AppointmentError:new(
            type(err) == 'table' and err.err or err
        )
    end

    return true
end

return {
    role_name = 'failover-coordinator',
    apply_config = apply_config,
    stop = stop,

    -- rpc
    appoint_leaders = appoint_leaders,
}
