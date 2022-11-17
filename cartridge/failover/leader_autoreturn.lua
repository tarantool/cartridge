local fiber = require('fiber')
local log = require('log')
local topology = require('cartridge.topology')

local vars = require('cartridge.vars').new('cartridge.failover')
vars:new('autoreturn_fiber', nil)
vars:new('autoreturn_delay', math.huge)

--- Loop to check is there any leaders that not on its place.
--
-- Used in 'stateful' failover mode.
-- @function enable
-- @local
local function enable(topology_cfg)
    while true do
        fiber.sleep(vars.autoreturn_delay or math.huge)
        if vars.cache.is_leader then
            local leaders = topology.get_leaders_order(
                topology_cfg, vars.replicaset_uuid, nil, {only_enabled = true}
            )
            local desired_leader_uuid = leaders[1]
            if desired_leader_uuid ~= vars.instance_uuid then
                log.info("Autoreturn: try to return leader %s in replicaset %s",
                    desired_leader_uuid, vars.replicaset_uuid)
                local client = vars.client
                if client == nil
                or client.session == nil
                or not client.session:is_alive()
                then
                    log.error('Autoreturn failed: state provider unavailable')
                else
                    local coordinator, err = vars.client.session:get_coordinator()
                    if coordinator ~= nil and err == nil then
                        local _, err = package.loaded['cartridge.rpc'].call(
                            'failover-coordinator',
                            'appoint_leaders',
                            {{[vars.replicaset_uuid] = desired_leader_uuid}},
                            { uri = coordinator.uri }
                        )
                        if err ~= nil then
                            log.error('Autoreturn failed: %s', err.err)
                        else
                            log.info('Autoreturn succeded')
                        end
                    elseif err ~= nil then
                        log.error('Autoreturn failed: %s', err.err)
                    elseif coordinator ~= nil then
                        log.error('Autoreturn failed: there is no active coordinator')
                    end
                end
            end
        end
    end
end

--- Сancel autoreturn loop.
--
-- Used in 'stateful' failover mode.
-- @function cancel
local function cancel()
    if vars.autoreturn_fiber == nil then
        return
    end
    if vars.autoreturn_fiber:status() ~= 'dead' then
        vars.autoreturn_fiber:cancel()
    end
    vars.autoreturn_fiber = nil
end

--- Configure and start autoreturn loop.
--
-- Used in 'stateful' failover mode.
-- @function cfg
local function cfg(failover_cfg, topology_cfg)
    local leaders = topology.get_leaders_order(
        topology_cfg, vars.replicaset_uuid, nil, {only_enabled = true}
    )
    if #leaders < 2 then
        log.info("Not enough enabled instances to start leader_autoreturn fiber")
        return
    end
    if failover_cfg.leader_autoreturn == true then
        vars.autoreturn_delay = failover_cfg.autoreturn_delay
        vars.autoreturn_fiber = fiber.new(enable, topology_cfg)
        vars.autoreturn_fiber:name('cartridge.leader_autoreturn')
    end
end

return {
    cancel = cancel,
    cfg = cfg,
}
