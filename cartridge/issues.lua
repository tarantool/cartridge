--- Monitor issues across cluster instances.
--
-- Cartridge detects the following problems:
--
-- Replication:
--
-- * "Replication from ... to ... isn't running" -
--   when `box.info.replication.upstream == nil`;
-- * "Replication from ... to ... is stopped/orphan/etc. (...)";
-- * "Replication from ... to ...: high lag" -
--   when `upstream.lag > box.cfg.replication_sync_lag`;
-- * "Replication from ... to ...: long idle" -
--   when `upstream.idle > box.cfg.replication_timeout`;
--
-- Failover:
--
-- * "Can't obtain failover coordinator (...)";
-- * "There is no active failover coordinator";
-- * "Failover is stuck on ...: Error fetching appointments (...)";
-- * "Failover is stuck on ...: Failover fiber is dead" -
--   this is likely a bug;

-- Switchover:
-- * "Consistency on ... isn't reached yet";
--
-- Clock:
--
-- * "Clock difference between ... and ... exceed threshold"
--  `limits.clock_delta_threshold_warning`;
--
-- Memory:
--
-- * "Running out of memory on ..." - when all 3 metrics
--   `items_used_ratio`, `arena_used_ratio`, `quota_used_ratio` from
--   `box.slab.info()` exceed `limits.fragmentation_threshold_critical`;
-- * "Memory is highly fragmented on ..." - when
--   `items_used_ratio > limits.fragmentation_threshold_warning` and
--   both `arena_used_ratio`, `quota_used_ratio` exceed critical limit.
--
-- @module cartridge.issues
-- @local

local fun = require('fun')
local checks = require('checks')
local pool = require('cartridge.pool')
local topology = require('cartridge.topology')
local confapplier = require('cartridge.confapplier')
local failover = require('cartridge.failover')
local membership = require('membership')
local vars = require('cartridge.vars').new('cartridge.issues')

--- Thresholds for issuing warnings.
-- All settings are local, not clusterwide. They can be changed with
-- corresponding environment variables (`TARANTOOL_*`) or command-line
-- arguments. See `cartridge.argparse` module for details.
--
-- @table limits
local default_limits = {
    fragmentation_threshold_critical = 0.9, -- number: *default*: 0.9.
    fragmentation_threshold_warning  = 0.6, -- number: *default*: 0.6.
    clock_delta_threshold_warning    = 5, -- number: *default*: 5.
}
vars:new('limits', default_limits)

local function describe(uri)
    local member = membership.get_member(uri)
    if member ~= nil and member.payload.alias ~= nil then
        return string.format('%s (%s)', uri, member.payload.alias)
    else
        return uri
    end
end

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
                    describe(replica.uri),
                    describe(self_uri)
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
                    describe(replica.uri),
                    describe(self_uri),
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
                    describe(replica.uri),
                    describe(self_uri),
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
                    describe(replica.uri),
                    describe(self_uri),
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
                describe(self_uri),
                failover_error.err
            ),
        })
    end

    -- It should be a vclockkeeper, but it's not
    if failover.consistency_needed()
    and failover.get_active_leaders()[replicaset_uuid] == instance_uuid
    and not failover.is_vclockkeeper()
    then
        table.insert(ret, {
            level = 'warning',
            topic = 'switchover',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = string.format(
                "Consistency on %s isn't reached yet",
                describe(self_uri)
            ),
        })
    end

    -- used_ratio values in box.slab.info() are strings
    -- so we calulate them again manually
    -- Magic formula taken from tarantool src/box/lua/slab.c
    -- See also: http://kostja.github.io/misc/2017/02/17/tarantool-memory.html
    -- See also: https://github.com/tarantool/doc/issues/421
    local slab_info = box.slab.info()
    local items_used_ratio = slab_info.items_used / (slab_info.items_size + 0.0001)
    local arena_used_ratio = slab_info.arena_used / (slab_info.arena_size + 0.0001)
    local quota_used_ratio = slab_info.quota_used / (slab_info.quota_size + 0.0001)

    if  items_used_ratio > vars.limits.fragmentation_threshold_critical
    and arena_used_ratio > vars.limits.fragmentation_threshold_critical
    and quota_used_ratio > vars.limits.fragmentation_threshold_critical
    then
        table.insert(ret, {
            level = 'critical',
            topic = 'memory',
            instance_uuid = instance_uuid,
            message = string.format(
                'Running out of memory on %s:' ..
                ' used %s (items), %s (arena), %s (quota)',
                describe(self_uri),
                slab_info.items_used_ratio,
                slab_info.arena_used_ratio,
                slab_info.quota_used_ratio
            ),
        })
    elseif items_used_ratio > vars.limits.fragmentation_threshold_warning
    and arena_used_ratio > vars.limits.fragmentation_threshold_critical
    and quota_used_ratio > vars.limits.fragmentation_threshold_critical
    then
        table.insert(ret, {
            level = 'warning',
            topic = 'memory',
            instance_uuid = instance_uuid,
            message = string.format(
                'Memory is highly fragmented on %s:' ..
                ' used %s (items), %s (arena), %s (quota)',
                describe(self_uri),
                slab_info.items_used_ratio,
                slab_info.arena_used_ratio,
                slab_info.quota_used_ratio
            ),
        })
    end

    return ret
end

local function list_on_cluster()
    local ret = {}
    local uri_list = {}
    local topology_cfg = confapplier.get_readonly('topology')

    if topology_cfg == nil then
        return ret
    end

    for _, _, srv in fun.filter(topology.not_disabled, topology_cfg.servers) do
        table.insert(uri_list, srv.uri)
    end

    -- Check clock desynchronization

    local min_delta = 0
    local max_delta = 0
    local min_delta_uri = topology_cfg.servers[box.info.uuid].uri
    local max_delta_uri = topology_cfg.servers[box.info.uuid].uri
    local members = membership.members()
    for _, server_uri in pairs(uri_list) do
        local member = members[server_uri]
        if member and member.status == 'alive' and member.clock_delta ~= nil then
            if member.clock_delta < min_delta then
                min_delta = member.clock_delta
                min_delta_uri = server_uri
            end

            if member.clock_delta > max_delta then
                max_delta = member.clock_delta
                max_delta_uri = server_uri
            end
        end
    end

    -- difference in seconds
    local diff = (max_delta - min_delta) * 1e-6
    if diff > vars.limits.clock_delta_threshold_warning then
        table.insert(ret, {
            level = 'warning',
            topic = 'clock',
            message = string.format(
                'Clock difference between %s and %s' ..
                ' exceed threshold (%.2g > %g)',
                describe(min_delta_uri), describe(max_delta_uri),
                diff, vars.limits.clock_delta_threshold_warning
            )
        })
    end

    -- Check stateful failover issues

    local failover_cfg = topology.get_failover_params(topology_cfg)
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

    -- Get each instance issues (replication, failover, memory usage)

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

local function set_limits(limits)
    checks({
        fragmentation_threshold_critical = '?number',
        fragmentation_threshold_warning = '?number',
        clock_delta_threshold_warning = '?number',
    })
    vars.limits = fun.chain(vars.limits, limits):tomap()
    return true
end

_G.__cartridge_issues_list_on_instance = list_on_instance

return {
    list_on_cluster = list_on_cluster,
    set_limits = set_limits,
}
