local fun = require('fun')
local pool = require('cartridge.pool')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local failover = require('cartridge.failover')
local errors = require('errors')

local function list_on_instance(check_failover)
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

    if check_failover then
        local failover_issues = failover.get_stateful_issues()
        for _, issue in ipairs(failover_issues) do
            table.insert(ret, {
                level = 'warning',
                instance_uuid = instance_uuid,
                message = issue,
                topic = 'failover'
            })
        end
    end
    return ret
end

local function is_kingdom_alive()
    local conn = failover.get_kingdom_conn()
    if conn == nil then
        return nil, string.format("Can't connect to kigdom, seems it's fallen")
    end

    local coordinator, err = errors.netbox_call(
        conn,
        '_G.get_coordinator',
        {}, {timeout = 5}
    )
    if err ~= nil then
        return nil, string.format(
            "Can't get active coordinators from kigdom, seems it's fallen: %s", err.err
        )
    end

    if coordinator == nil then
        return nil, 'There is no active coordinator in kingdom'
    end
    return true
end

local function list_on_cluster()
    local uri_list = {}
    local topology_cfg = confapplier.get_readonly('topology')
    local failover_cfg = topology.get_failover_params(topology_cfg)
    for _, _, srv in fun.filter(topology.not_disabled, topology_cfg.servers) do
        table.insert(uri_list, srv.uri)
    end

    local ret = {}
    local check_failover = false
    if failover_cfg.mode == 'stateful' then
        local ok, err = is_kingdom_alive()
        if ok then
            check_failover = true
        else
            table.insert(ret, {
                level = 'critical',
                topic = 'failover',
                message = err,
            })
        end
    end

    local issues_map = pool.map_call(
        '_G.__cartridge_issues_list_on_instance',
        {check_failover}, {uri_list = uri_list, timeout = 5}
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
