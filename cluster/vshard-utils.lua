#!/usr/bin/env tarantool
-- luacheck: ignore _it

local fun = require('fun')
local pool = require('cluster.pool')
local topology = require('cluster.topology')

-- returns SHARDING table, which can be passed to
-- vshard.router.cfg{sharding = SHARDING} and
-- vshard.storage.cfg{sharding = SHARDING}
local function get_sharding_config()
    local sharding = {}
    local topology_cfg = topology.get()
    local active_masters = topology.get_active_masters()

    for _it, instance_uuid, server in fun.filter(topology.not_disabled, topology_cfg.servers) do
        local replicaset_uuid = server.replicaset_uuid
        local replicaset = topology_cfg.replicasets[replicaset_uuid]
        if replicaset.roles['vshard-storage'] then
            if sharding[replicaset_uuid] == nil then
                sharding[replicaset_uuid] = {
                    replicas = {},
                    weight = replicaset.weight or 0.0,
                }
            end

            local replicas = sharding[replicaset_uuid].replicas
            replicas[instance_uuid] = {
                name = server.uri,
                uri = pool.format_uri(server.uri),
                master = (active_masters[replicaset_uuid] == instance_uuid),
            }
        end
    end

    return sharding
end

return {
    get_sharding_config = get_sharding_config,
}
