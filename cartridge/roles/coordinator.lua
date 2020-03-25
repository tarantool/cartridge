local log = require('log')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')
local membership = require('membership')
local uri_lib = require('uri')

local vars = require('cartridge.vars').new('cartridge.roles.coordinator')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')

local AppointmentError = errors.new_class('AppointmentError')
local CoordinatorError = errors.new_class('CoordinatorError')
local NetboxConnectError = errors.new_class('NetboxConnectError')

vars:new('membership_notification', membership.subscribe())
vars:new('connect_fiber', nil)
vars:new('topology_cfg', nil)
vars:new('conn', nil)
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
        immunity = fiber.time() + vars.options.IMMUNITY_TIMEOUT,
    }
end

local function make_decision(ctx, replicaset_uuid)
    checks({members = 'table', decisions = 'table'}, 'string')

    local current_decision = ctx.decisions[replicaset_uuid]
    if current_decision ~= nil then
        if fiber.time() < current_decision.immunity
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

local function control_loop(conn)
    local leaders, err = errors.netbox_call(conn, 'get_leaders',
        nil, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
    )
    if leaders == nil then
        log.error('%s', err)
        return
    end

    local ctx = {
        members = nil,
        decisions = {},
    }

    for replicaset_uuid, leader_uuid in pairs(leaders) do
        ctx.decisions[replicaset_uuid] = pack_decision(leader_uuid)
    end

    repeat
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

        if next(updates) ~= nil then
            local ok, err = errors.netbox_call(conn, 'set_leaders',
                {updates}, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
            )
            if ok == nil then
                log.error('%s', err)
                break
            end
        end

        local now = fiber.time()
        local next_moment = math.huge
        for _, decision in pairs(ctx.decisions) do
            if (now < decision.immunity)
            and (decision.immunity < next_moment)
            then
                next_moment = decision.immunity
            end
        end

        vars.membership_notification:wait(next_moment - now)
    until not pcall(fiber.testcancel)
end

local function take_control(uri)
    checks('string')
    local conn, err = NetboxConnectError:pcall(netbox.connect, uri)
    if conn == nil then
        return nil, err
    elseif not conn:is_connected() then
        return nil, NetboxConnectError:new('"%s:%s": %s',
            conn.host, conn.port, conn.error
        )
    end

    local lock_delay, err = errors.netbox_call(conn, 'get_lock_delay',
        nil, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
    )
    if lock_delay == nil then
        return nil, err
    end

    local lock_args = {
        confapplier.get_instance_uuid(),
        confapplier.get_advertise_uri()
    }

    local ok, err = errors.netbox_call(conn, 'acquire_lock',
        lock_args, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
    )

    if ok == nil then
        return nil, err
    end

    if ok ~= true then
        return false
    end

    log.info('Lock acquired')
    vars.conn = conn
    local control_fiber = fiber.new(control_loop, conn)
    control_fiber:name('failover-coordinate')

    repeat
        -- Warning: fragile code.
        -- Cancelled fibers raise error on every yield
        if not pcall(fiber.sleep, lock_delay/2) then
            break
        end

        if pcall(fiber.status, control_fiber) == 'dead'
        or not errors.netbox_call(conn, 'acquire_lock',
            lock_args, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
        ) then
            break
        end
    until not pcall(fiber.testcancel)

    pcall(conn.close, conn)
    pcall(fiber.cancel, control_fiber)
    vars.conn = nil

    log.info('Lock released')
    return true
end

local function connect_loop(uri)
    checks('string')
    repeat
        local t1 = fiber.time()
        local ok, err = CoordinatorError:pcall(take_control, uri)
        local t2 = fiber.time()

        if ok == nil then
            log.error('%s', type(err) == 'table' and err.err or err)
        end

        if ok ~= true then
            fiber.sleep(t1 + vars.options.RECONNECT_PERIOD - t2)
        end

    until not pcall(fiber.testcancel)
end

local function stop()
    if vars.connect_fiber == nil then
        return
    elseif vars.connect_fiber:status() ~= 'dead' then
        vars.connect_fiber:cancel()
    end

    vars.connect_fiber = nil
end

local function apply_config(conf, _)
    vars.topology_cfg = conf.topology
    local failover_cfg = topology.get_failover_params(conf.topology)

    if failover_cfg.mode ~= 'stateful' then
        stop()
        return true
    end

    if failover_cfg.state_provider ~= 'tarantool' then
        local err = string.format(
            'assertion failed! unknown state_provider %s',
            failover_cfg.state_provider
        )
        error(err)
    end

    if vars.connect_fiber == nil
    or vars.connect_fiber:status() == 'dead'
    then
        log.info(
            'Starting failover coordinator' ..
            ' with external storage at %s',
            failover_cfg.tarantool_params.uri
        )

        local parts = uri_lib.parse(failover_cfg.tarantool_params.uri)
        parts.login = 'client'
        parts.password = failover_cfg.tarantool_params.password
        local storage_uri = uri_lib.format(parts, true)

        vars.connect_fiber = fiber.new(connect_loop, storage_uri)
        vars.connect_fiber:name('failover-connect-kv')
    end
    vars.membership_notification:broadcast()
    return true
end

--- Manually set leaders.
-- @function appoint_leaders
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function appoint_leaders(leaders)
    checks('table')

    local servers = vars.topology_cfg.servers
    local replicasets = vars.topology_cfg.replicasets

    local updates = {}
    for k, v in pairs(leaders) do
        if type(k) ~= 'string' or type(v) ~= 'string' then
            error('bad argument #1 to appoint_leaders' ..
                ' (keys and values must be strings)', 2
            )
        end

        local replicaset = replicasets[k]
        if replicaset == nil then
            return nil, AppointmentError:new('Replicaset "%s" does not exist', k)
        end

        local server = servers[v]
        if server == nil then
            return nil, AppointmentError:new('Server "%s" does not exist', v)
        end

        if server.replicaset_uuid ~= k then
            return nil, AppointmentError:new('Server "%s" does not belong to replicaset "%s"', v, k)
        end

        table.insert(updates, {k, v})
    end

    if vars.conn == nil then
        return nil, AppointmentError:new("Lock not acquired")
    end

    local ok, err = errors.netbox_call(vars.conn, 'set_leaders',
        {updates}, {timeout = vars.options.NETBOX_CALL_TIMEOUT}
    )
    if ok == nil then
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
