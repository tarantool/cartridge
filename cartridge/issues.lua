--- Monitor issues across cluster instances.
--
-- Cartridge detects the following problems:
--
-- Replication:
--
-- * critical: "Replication from ... to ... isn't running" -
--   when `box.info.replication.upstream == nil`;
-- * critical: "Replication from ... to ... state "stopped"/"orphan"/etc. (...)";
-- * warning: "Replication from ... to ...: high lag" -
--   when `upstream.lag > box.cfg.replication_sync_lag`;
-- * warning: "Replication from ... to ...: long idle" -
--   when `upstream.idle > 2 * box.cfg.replication_timeout`;
--
-- Failover:
--
-- * warning: "Can't obtain failover coordinator (...)";
-- * warning: "There is no active failover coordinator";
-- * warning: "Failover is stuck on ...: Error fetching appointments (...)";
-- * warning: "Failover is stuck on ...: Failover fiber is dead" -
--   this is likely a bug;
--
-- Switchover:
--
-- * warning: "Consistency on ... isn't reached yet";
--
-- Clock:
--
-- * warning: "Clock difference between ... and ... exceed threshold"
--  `limits.clock_delta_threshold_warning`;
--
-- Memory:
--
-- * critical: "Running out of memory on ..." - when all 3 metrics
--   `items_used_ratio`, `arena_used_ratio`, `quota_used_ratio` from
--   `box.slab.info()` exceed `limits.fragmentation_threshold_critical`;
-- * warning: "Memory is highly fragmented on ..." - when
--   `items_used_ratio > limits.fragmentation_threshold_warning` and
--   both `arena_used_ratio`, `quota_used_ratio` exceed critical limit;
--
-- Configuration:
--
-- * warning: "Configuration checksum mismatch on ...";
-- * warning: "Configuration is prepared and locked on ...";
-- * warning: "Advertise URI (...) differs from clusterwide config (...)";
-- * warning: "Configuring roles is stuck on ... and hangs for ... so far";
--
-- Vshard:
--
-- * various vshard alerts (see vshard docs for details);
-- * warning: "Group "..." wasn't bootstrapped: ...";
-- * warning: Vshard storages in replicaset %s marked as "all writable".
-- * warning: "Cluster has ... doubled buckets. Call
--   require('cartridge.vshard-utils').find_doubled_buckets() for details";
-- You can enable extra vshard issues by setting
-- `TARANTOOL_ADD_VSHARD_STORAGE_ALERTS_TO_ISSUES=true/TARANTOOL_ADD_VSHARD_ROUTER_ALERTS_TO_ISSUES=true`
-- or with `--add-vshard-storage-alerts-to-issues/--add-vshard-router-alerts-to-issues` command-line argument.
-- It's recommended to enable router alerts in production.
--
-- Alien members:
--
-- * warning: "Instance ... with alien uuid is in the membership" -
--   when two separate clusters share the same cluster cookie;
--
-- Expelled instances:
--
-- * warning: "Replicaset ... has expelled instance ... in box.space._cluster" -
--   when instance was expelled from replicaset, but still remains in box.space._cluster;
--
-- Deprecated space format:
--
-- * warning: "Instance ... has spaces with deprecated format: space1, ..."
--
-- Raft issues:
--
-- * warning: "Raft leader idle is 10.000 on ... .
--   Is raft leader alive and connection is healthy?"
--
-- Unhealthy replicasets:
--
-- * critical: "All instances are unhealthy in replicaset ... ".
--
-- Disk failures:
--
-- * critical: "Disk error on instance ... ".
--
-- Disabled instances:
--
-- * warning: "Instance had Error and was disabled"
--
-- Custom issues (defined by user):
--
-- * Custom roles can announce more issues with their own level, topic
--   and message. See `custom-role.get_issues`.
--
-- GraphQL request:
--
-- You can get info about cluster issues using the following GraphQL request:
--    {
--        cluster {
--            issues {
--                level
--                message
--                replicaset_uuid
--                instance_uuid
--                topic
--             }
--         }
--     }

-- @module cartridge.issues
-- @local
local mod_name = 'cartridge.issues'

local fio = require('fio')
local log = require('log')
local fun = require('fun')
local fiber = require('fiber')
local errors = require('errors')
local membership = require('membership')

local pool = require('cartridge.pool')
local topology = require('cartridge.topology')
local failover = require('cartridge.failover')
local confapplier = require('cartridge.confapplier')
local lua_api_proxy = require('cartridge.lua-api.proxy')
local lua_api_topology = require('cartridge.lua-api.topology')
local invalid_format = require('cartridge.invalid-format')
local sync_spaces = require('cartridge.sync-spaces')
local vshard_utils = require('cartridge.vshard-utils')

local ValidateConfigError = errors.new_class('ValidateConfigError')

local vars = require('cartridge.vars').new(mod_name)

--- Thresholds for issuing warnings.
-- All settings are local, not clusterwide. They can be changed with
-- corresponding environment variables (`TARANTOOL_*`) or command-line
-- arguments. See `cartridge.argparse` module for details.
--
-- @table limits
local default_limits = {
    fragmentation_threshold_critical = 0.85, -- number: *default*: 0.85.
    fragmentation_threshold_full = 1.0, -- number: *default*: 1.0.
    fragmentation_threshold_warning  = 0.6, -- number: *default*: 0.6.
    clock_delta_threshold_warning    = 5, -- number: *default*: 5.
}

-- Min and max values for issues_limits theshold
-- range[1] <= value <= range[2]
local limits_ranges = {
    fragmentation_threshold_warning = {0, 1},
    fragmentation_threshold_critical = {0, 1},
    fragmentation_threshold_full = {0, 1},
    clock_delta_threshold_warning = {0, math.huge},
}

vars:new('limits', default_limits)
vars:new('disable_unrecoverable', false)
vars:new('check_doubled_buckets', false)
vars:new('check_doubled_buckets_period', 24*60*60) -- 24 hours

vars:new('instance_uuid')
vars:new('replicaset_uuid')

local function describe(uri)
    local member = membership.get_member(uri)
    if member ~= nil and member.payload.alias ~= nil then
        return string.format('%s (%s)', uri, member.payload.alias)
    else
        return uri
    end
end

local function gather_role_issues(ret, role_name, M)
    if type(M.get_issues) ~= 'function' then
        return
    end

    local custom_issues = M.get_issues()

    if type(custom_issues) ~= 'table' then
        error(string.format(
            'malformed return: %s', custom_issues
        ), 0)
    end

    for i, issue in pairs(custom_issues) do
        if type(i) ~= 'number' or type(issue) ~= 'table' then
            error(string.format(
                'malformed return: [%s] = %s', i, issue
            ), 0)
        end

        table.insert(ret, {
            level = tostring(issue.level or 'warning'),
            topic = tostring(issue.topic or role_name),
            message = tostring(issue.message),
            instance_uuid = vars.instance_uuid,
            replicaset_uuid = vars.replicaset_uuid,
        })
    end
end

local function list_on_instance(opts)
    local enabled_servers = {}
    local topology_cfg = confapplier.get_readonly('topology')
    for _, uuid, server in fun.filter(topology.not_disabled, topology_cfg.servers) do
        enabled_servers[uuid] = server
    end

    local ret = {}
    local instance_uuid = vars.instance_uuid
    local replicaset_uuid = vars.replicaset_uuid
    if replicaset_uuid == nil or instance_uuid == nil then
        local box_info = box.info
        instance_uuid = box_info.uuid
        replicaset_uuid = box_info.cluster.uuid
        vars.instance_uuid = instance_uuid
        vars.replicaset_uuid = replicaset_uuid
    end

    local self_uri = enabled_servers[instance_uuid].uri
    local instance_uri = confapplier.get_advertise_uri()

    if instance_uri ~= self_uri then
        local issue = {
            level = 'warning',
            topic = 'configuration',
            replicaset_uuid = replicaset_uuid,
            instance_uuid = instance_uuid,
            message = string.format(
                "Advertise URI (%s)"..
                " differs from clusterwide config (%s)",
                instance_uri,
                self_uri
            )
        }
        table.insert(ret, issue)
    end
    local box_info = box.info
    for _, replication_info in pairs(box_info.replication) do
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
                level = 'critical',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                upstream_uuid = replication_info.uuid,
                message = string.format(
                    "Replication from %s to %s isn't running",
                    describe(replica.uri),
                    describe(self_uri)
                )
            }
            table.insert(ret, issue)
        elseif upstream.status ~= 'follow' and upstream.status ~= 'sync' then
            local issue = {
                level = 'critical',
                topic = 'replication',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                upstream_uuid = replication_info.uuid,
                message = string.format(
                    'Replication from %s to %s state %q (%s)',
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
        elseif upstream.idle > 2 * box.cfg.replication_timeout then
            -- https://www.tarantool.io/en/doc/latest/reference/configuration/#cfg-replication-replication-timeout

            -- If the master has no updates to send to the replicas, it sends
            -- heartbeat messages every `replication_timeout` seconds, and each
            -- replica sends an ACK packet back.

            -- Both master and replicas are programmed to drop the connection if
            -- they get no response in four `replication_timeout periods`. If the
            -- connection is dropped, a replica tries to reconnect to the
            -- master.

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
                    -- the message ignores threshold (2x multiplier)
                    box.cfg.replication_timeout
                )
            }
            table.insert(ret, issue)
        end

        ::continue::
    end

    if box_info.election then
        local leader_idle = box_info.election.leader_idle
        if leader_idle ~= nil
        and leader_idle >= 4 * box.cfg.replication_timeout then
            local issue = {
                level = 'warning',
                topic = 'raft',
                replicaset_uuid = replicaset_uuid,
                instance_uuid = instance_uuid,
                message = string.format(
                    "Raft leader idle is %f on %s. "..
                    "Is raft leader alive and connection is healthy?",
                    leader_idle,
                    describe(self_uri)
                )
            }
            table.insert(ret, issue)
        end
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

    local sync_spaces_list = sync_spaces.spaces_list_str()
    if sync_spaces_list ~= ''
    and (failover.is_leader()
    and (failover.mode() == 'eventual'
    or (failover.mode() == 'stateful' and not failover.is_synchro_mode_enabled()))) then
        table.insert(ret, {
            level = 'warning',
            topic = 'failover',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = 'Having sync spaces may cause failover errors. ' ..
                'Consider to change failover type to stateful and enable synchro_mode or use ' ..
                'raft failover mode. Sync spaces: ' .. sync_spaces_list
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
    local total_used_ratio =
        (slab_info.arena_used + slab_info.quota_used - slab_info.arena_size) / (slab_info.quota_size + 0.0001)

    if  items_used_ratio > vars.limits.fragmentation_threshold_critical
    and arena_used_ratio > vars.limits.fragmentation_threshold_critical
    and quota_used_ratio > vars.limits.fragmentation_threshold_critical
    or  total_used_ratio > vars.limits.fragmentation_threshold_critical
    or  items_used_ratio >= vars.limits.fragmentation_threshold_full
    or  quota_used_ratio >= vars.limits.fragmentation_threshold_full
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

    local checksum = confapplier.get_active_config():get_checksum()
    if opts ~= nil
    and opts.checksum ~= nil
    and opts.checksum ~= checksum
    then
        log.verbose(
            'Config checksum mismatch:' ..
            ' %s (local) vs %s (remote)',
            checksum, opts.checksum
        )

        table.insert(ret, {
            level = 'warning',
            topic = 'config_mismatch',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = string.format(
                'Configuration checksum mismatch on %s',
                describe(self_uri)
            ),
        })
    end

    local workdir = confapplier.get_workdir()
    local path_prepare = fio.pathjoin(workdir, 'config.prepare')
    if opts ~= nil
    and opts.check_2pc_lock == true
    and fio.path.exists(path_prepare) then
        table.insert(ret, {
            level = 'warning',
            topic = 'config_locked',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = string.format(
                'Configuration is prepared and locked on %s',
                describe(self_uri)
            ),
        })
    end

    if confapplier.get_state() == 'ConfiguringRoles' then
        local confapplier_vars = require('cartridge.vars').new('cartridge.confapplier')
        local elapsed = fiber.clock() - confapplier_vars.state_timestamp
        local timeout = confapplier_vars.state_notification_timeout
        if elapsed > timeout then
            table.insert(ret, {
                level = 'warning',
                topic = 'state_stuck',
                instance_uuid = instance_uuid,
                replicaset_uuid = replicaset_uuid,
                message = string.format(
                    'Configuring roles is stuck on %s' ..
                    ' and hangs for %ds so far',
                    describe(self_uri), elapsed
                ),
            })
        end
    end

    local invalid_spaces = invalid_format.spaces_list_str()
    if invalid_spaces ~= '' then
        table.insert(ret, {
            level = 'warning',
            topic = 'invalid_format',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = string.format(
                'Instance %s has spaces with deprecated format: %s',
                describe(self_uri), invalid_spaces
            ),
        })
    end

    if failover.is_leader() then
        for _, uuid, _ in fun.filter(topology.expelled, topology_cfg.servers) do
            if box.space._cluster.index.uuid:get(uuid) ~= nil then
                table.insert(ret, {
                    level = 'warning',
                    topic = 'expelled',
                    instance_uuid = instance_uuid,
                    replicaset_uuid = replicaset_uuid,
                    message = string.format(
                        'Replicaset %s has expelled instance %s in box.space._cluster',
                        replicaset_uuid, uuid
                    ),
                })
            end
        end
    end

    if type(box.cfg) == 'table' and not fio.lstat(box.cfg.memtx_dir) then
        table.insert(ret, {
            level = 'critical',
            topic = 'disk_failure',
            instance_uuid = instance_uuid,
            replicaset_uuid = replicaset_uuid,
            message = string.format(
                'Disk error on instance %s. This issue stays until restart',
                describe(self_uri)
            ),
        })
    end

    -- add custom issues from each role
    local registry = require('cartridge.service-registry')
    for role_name, M in pairs(registry.list()) do
        local ok, err = pcall(gather_role_issues, ret, role_name, M)
        if not ok then
            table.insert(ret, {
                level = 'warning',
                topic = role_name,
                instance_uuid = instance_uuid,
                replicaset_uuid = replicaset_uuid,
                message = string.format(
                    'Role %s get_issues() failed: %s',
                    role_name, err
                ),
            })
        end
    end

    return ret
end

local disk_failure_cache = {}
local doubled_buckets_count_cache = 0
local last_doubled_buckets_check = fiber.time()
local function list_on_cluster()
    local state, err = confapplier.get_state()
    if state == 'Unconfigured' and lua_api_proxy.can_call()  then
        -- Try to proxy call
        local ret = lua_api_proxy.call(mod_name .. '.list_on_cluster')
        if ret ~= nil then
            return ret
        -- else
            -- Don't return an error, go on
        end
    elseif state == 'InitError' or state == 'BootError' then
        return nil, err
    end

    local ret = {}
    local uri_list = {}
    local topology_cfg = confapplier.get_readonly('topology')

    if topology_cfg == nil then
        return ret
    end

    local refined_uri_list = topology.refine_servers_uri(topology_cfg)
    for _, uuid, _ in fun.filter(topology.not_disabled, topology_cfg.servers) do
        table.insert(uri_list, refined_uri_list[uuid])
    end

    if vars.replicaset_uuid == nil or vars.instance_uuid == nil then
        local box_info = box.info
        vars.instance_uuid = box_info.uuid
        vars.replicaset_uuid = box_info.cluster.uuid
    end

    -- Unhealthy replicasets
    for rs_uuid, replicaset in pairs(topology_cfg.replicasets) do
        local all_disabled = true
        for _, uuid in ipairs(replicaset.master) do
            local server = topology_cfg.servers[uuid]
            if server ~= nil then
                if not server.disabled then
                    all_disabled = false
                end
                if topology.member_is_healthy(server.uri, uuid) then
                    goto next_replicaset
                end
            end
        end

        if not all_disabled then
            table.insert(ret, {
                level = 'critical',
                topic = 'unhealthy_replicasets',
                replicaset_uuid = rs_uuid,
                message = string.format(
                    'All instances are unhealthy in replicaset %s',
                    rs_uuid
                )
            })
        end

        ::next_replicaset::
    end

    -- Check clock desynchronization

    local min_delta = 0
    local max_delta = 0
    local min_delta_uri = topology_cfg.servers[vars.instance_uuid].uri
    local max_delta_uri = topology_cfg.servers[vars.instance_uuid].uri
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

    if failover.mode() == 'stateful' then
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

        local check_cookie_error = failover.check_cookie_hash_error()
        if check_cookie_error ~= nil then
            table.insert(ret, {
                level = 'error',
                topic = 'failover',
                message = string.format(
                    'Last cookie hash check errored: %s. This issue stays until apply config or restart',
                    check_cookie_error.err
                ),
            })
        end
    end

    -- Check aliens in membership and unrecoverable instances
    local unrecoverable_uuids = {}
    for uri, member in membership.pairs() do
        local uuid = member.payload.uuid
        if member.status == 'alive'
        and uuid ~= nil
        and topology_cfg.servers[uuid] == nil
        then
            table.insert(ret, {
                level = 'warning',
                topic = 'aliens',
                message = string.format(
                    'Instance %s with alien uuid is in the membership',
                    describe(uri)
                )
            })
        end
        local state = member.payload.state
        if vars.disable_unrecoverable
        and (state == 'InitError' or state == 'BootError')
        then
            if uuid == nil then
                for k, v in pairs(topology_cfg.servers) do
                    if v.uri == uri then
                        uuid = k
                        goto uuid_found
                    end
                end
            end

            ::uuid_found::
            if uuid ~= nil then -- still no uuid, skipping
                table.insert(unrecoverable_uuids, uuid)
                table.insert(ret, {
                    level = 'warning',
                    topic = 'autodisable',
                    instance_uuid = uuid,
                    message = string.format(
                        'Instance %s had %s and was disabled',
                        describe(uri),
                        state
                    )
                })
            end
        end
    end

    if vars.check_doubled_buckets == true
    and last_doubled_buckets_check + vars.check_doubled_buckets_period > fiber.time()
    then
        local doubled_buckets = vshard_utils.find_doubled_buckets() or {}
        doubled_buckets_count_cache = 0
        for _ in pairs(doubled_buckets) do
            doubled_buckets_count_cache = doubled_buckets_count_cache + 1
        end
        last_doubled_buckets_check = fiber.time()
    end

    if doubled_buckets_count_cache > 0 then
        table.insert(ret, {
            level = 'warning',
            topic = 'vshard',
            message = string.format(
                "Cluster has %d doubled buckets. " ..
                "Call require('cartridge.vshard-utils').find_doubled_buckets() for details",
                doubled_buckets_count_cache
            )
        })
    end
    -- Get each instance issues (replication, failover, memory usage)

    local twophase_vars = require('cartridge.vars').new('cartridge.twophase')
    local patch_in_progress = assert(twophase_vars.locks)['clusterwide']

    local issues_map, err = pool.map_call(
        '_G.__cartridge_issues_list_on_instance',
        {{
            checksum = confapplier.get_active_config():get_checksum(),
            check_2pc_lock = not patch_in_progress,
        }},
        {uri_list = uri_list, timeout = 1}
    )

    local uuids_to_disable = {}
    for _, issues in pairs(issues_map) do
        for _, issue in pairs(issues) do
            table.insert(ret, issue)
            if issue.topic == 'disk_failure' then
                table.insert(uuids_to_disable, issue.instance_uuid)
                disk_failure_cache[issue.instance_uuid] = issue
            end
        end
    end

    for _, issue in pairs(disk_failure_cache) do
        table.insert(ret, issue)
    end

    if vars.disable_unrecoverable then
        uuids_to_disable = fun.chain(uuids_to_disable, unrecoverable_uuids):totable()
    end
    if #uuids_to_disable > 0 then
        lua_api_topology.disable_servers(uuids_to_disable)
    end

    -- to use this counter in tarantool/metrics
    rawset(_G, '__cartridge_issues_cnt', #ret)

    return ret, err
end

--- Validate limits configuration.
--
-- @function validate_limits
-- @local
-- @tparam table limits
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_limits(limits)
    if type(limits) ~= 'table' then
        return nil, ValidateConfigError:new(
            'limits must be a table, got %s', type(limits)
        )
    end

    for name, value in pairs(limits) do
        if type(name) ~= 'string' then
            return nil, ValidateConfigError:new(
                'limits table keys must be string, got %s', type(name)
            )
        end

        local range = limits_ranges[name]
        if range == nil then
            return nil, ValidateConfigError:new(
                'unknown limits key %q', name
            )
        elseif type(value) ~= 'number' then
            return nil, ValidateConfigError:new(
                'limits.%s must be a number, got %s',
                name, type(value)
            )
        elseif not (value >= range[1] and value <= range[2]) then
            return nil, ValidateConfigError:new(
                'limits.%s must be in range [%g, %g]',
                name, range[1], range[2]
            )
        end
    end

    return true
end

--- Update limits configuration.
--
-- @function set_limits
-- @local
-- @tparam table limits
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_limits(limits)
    local ok, err = validate_limits(limits)
    if not ok then
        return nil, err
    end

    vars.limits = fun.chain(vars.limits, limits):tomap()
    return true
end

_G.__cartridge_issues_list_on_instance = list_on_instance

return {
    list_on_cluster = list_on_cluster,
    default_limits = default_limits,
    validate_limits = validate_limits,
    set_limits = set_limits,
    disable_unrecoverable = function(disable)
        vars.disable_unrecoverable = disable
    end,
    check_doubled_buckets = function(check, period)
        vars.check_doubled_buckets = check
        if period ~= nil then
            vars.check_doubled_buckets_period = period
        end
    end,
}
