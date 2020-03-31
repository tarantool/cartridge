local fun = require('fun')
local pool = require('cartridge.pool')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local failover = require('cartridge.failover')
local vars = require('cartridge.vars').new('cartridge.issues')
vars:new('limits', {
    critical_fragmentation_treshold = 0.9,
    fragmentation_treshold = 0.6,
})

local function list_on_instance()
    local enabled_servers = {}
    local topology_cfg = confapplier.get_readonly('topology')
    for _, uuid, server in fun.filter(topology.not_disabled, topology_cfg.servers) do
        enabled_servers[uuid] = server
    end

    local ret = {}
    local instance_uuid = box.info.uuid
    local replicaset_uuid = box.info.cluster.uuid
    local self_uri = enabled_servers[instance_uuid].uri

    for _, replication_info in pairs(box.info.replication) do
        local replica = enabled_servers[replication_info.uuid]
        if replica == nil then
            goto continue
        end

        if instance_uuid == replication_info.uuid then
            goto continue
        end

        local upstream = replication_info.upstream
        if upstream == nil then
            local issue = {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                message = string.format(
                    "Replication from %s to %s isn't running",
                    replica.uri,
                    self_uri
                )
            }
            table.insert(ret, issue)
        elseif upstream.status ~= 'follow' and upstream.status ~= 'sync' then
            local issue = {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                message = string.format(
                    'Replication from %s to %s is %s (%s)',
                    replica.uri,
                    self_uri,
                    upstream.status,
                    upstream.message or ''
                )
            }
            table.insert(ret, issue)
        elseif upstream.lag > box.cfg.replication_sync_lag then
            local issue = {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                message = string.format(
                    'Replication from %s to %s: high lag (%.2g > %g)',
                    replica.uri,
                    self_uri,
                    upstream.lag,
                    box.cfg.replication_sync_lag
                )
            }
            table.insert(ret, issue)
        elseif upstream.idle > box.cfg.replication_timeout then
            -- A replica sends heartbeat messages to the master
            -- every second, and the master is programmed to
            -- reconnect automatically if it does not see heartbeat
            -- messages within replication_timeout seconds.
            --
            -- Therefore, in a healthy replication setup, idle
            -- should never exceed replication_timeout: if it does,
            -- either the replication is lagging seriously behind,
            -- because the master is running ahead of the replica,
            -- or the network link between the instances is down.
            local issue = {
                level = 'warning',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                message = string.format(
                    'Replication from %s to %s: long idle (%.2g > %g)',
                    replica.uri,
                    self_uri,
                    upstream.idle,
                    box.cfg.replication_timeout
                )
            }
            table.insert(ret, issue)
        end

        ::continue::
    end

    local failover_error = failover.get_error()
    if failover_error ~= nil then
        table.insert(ret, {
            level = 'warning',
            topic = 'failover',
            instance_uuid = instance_uuid,
            message = string.format(
                'Failover is stuck on %s: %s',
                self_uri, failover_error.err
            ),
        })
    end

    local mem_info = box.slab.info()
    local items_used_ratio = mem_info.items_used / (mem_info.items_size + 0.0001) -- to prevent divide by zero
    local arena_used_ratio = mem_info.arena_used / (mem_info.arena_size + 0.0001)
    local quota_used_ratio = mem_info.quota_used / (mem_info.quota_size + 0.0001)

    if arena_used_ratio > vars.limits.critical_fragmentation_treshold
    and quota_used_ratio > vars.limits.critical_fragmentation_treshold
    and items_used_ratio > vars.limits.critical_fragmentation_treshold
    then
        table.insert(ret, {
            level = 'critical',
            topic = 'memory',
            instance_uuid = instance_uuid,
            message = string.format(
                'Your memory is (highly) fragmented on %s.',
                self_uri
            ),
        })
    elseif arena_used_ratio > vars.limits.fragmentation_treshold
    and quota_used_ratio > vars.limits.fragmentation_treshold
    and items_used_ratio > vars.limits.fragmentation_treshold
    then
        table.insert(ret, {
            level = 'warning',
            topic = 'memory',
            instance_uuid = instance_uuid,
            message = string.format(
                'Your memory is fragmented on %s.',
                self_uri
            ),
        })
    end

    return ret
end

local function list_on_cluster()
    local uri_list = {}
    local topology_cfg = confapplier.get_readonly('topology')

    if topology_cfg == nil then
        return {}
    end

    local failover_cfg = topology.get_failover_params(topology_cfg)
    for _, _, srv in fun.filter(topology.not_disabled, topology_cfg.servers) do
        table.insert(uri_list, srv.uri)
    end

    local ret = {}
    if failover_cfg.mode == 'stateful' then
        local coordinator, err = failover.get_coordinator()

        if err ~= nil then
            table.insert(ret, {
                level = 'warning',
                topic = 'failover',
                message = string.format(
                    "Can't obtain failover coordinator: %s", err.err
                )
            })
        elseif coordinator == nil then
            table.insert(ret, {
                level = 'warning',
                topic = 'failover',
                message = 'There is no active failover coordinator'
            })
        end
    end

    local issues_map = pool.map_call(
        '_G.__cartridge_issues_list_on_instance',
        {}, {uri_list = uri_list, timeout = 1}
    )

    for _, issues in pairs(issues_map) do
        for _, issue in pairs(issues) do
            table.insert(ret, issue)
        end
    end
    return ret
end

_G.__cartridge_issues_list_on_instance = list_on_instance

return {
    list_on_cluster = list_on_cluster,
}
