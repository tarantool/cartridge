#!/usr/bin/env tarantool
-- luacheck: ignore _it

--- Administration functions.
--
-- @module cluster.admin

local fun = require('fun')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local uuid_lib = require('uuid')
local membership = require('membership')

local rpc = require('cluster.rpc')
local pool = require('cluster.pool')
local utils = require('cluster.utils')
local topology = require('cluster.topology')
local vshard_utils = require('cluster.vshard-utils')
local confapplier = require('cluster.confapplier')

local e_topology_edit = errors.new_class('Editing cluster topology failed')
local e_probe_server = errors.new_class('Can not probe server')

local function get_server_info(members, uuid, uri)
    local member = members[uri]
    local alias = nil
    if member and member.payload then
        alias = member.payload.alias
    end

    --- Instance general information.
    -- @tfield
    --   string alias
    --   Human-readable instance name.
    -- @tfield string uri
    -- @tfield string uuid
    -- @tfield boolean disabled
    -- @tfield
    --   string status
    --   Instance health.
    -- @tfield
    --   string message
    --   Auxilary health status.
    -- @tfield
    --   ReplicasetInfo replicaset
    --   Circular reference to a replicaset.
    -- @tfield
    --   number priority
    --   Leadership priority for automatic failover.
    -- @table ServerInfo
    local ret = {
        alias = alias,
        uri = uri,
        uuid = uuid,
    }

    -- find the most fresh information
    -- among the members with given uuid
    for _, m in pairs(members) do
        if m.payload.uuid == uuid
        and m.timestamp > (member.timestamp or 0) then
            member = m
        end
    end

    if not member or member.status == 'left' then
        ret.status = 'not found'
        ret.message = 'Server uri is not in membership'
    elseif member.payload.uuid ~= nil and member.payload.uuid ~= uuid then
        ret.status = 'not found'
        ret.message = string.format('Alien uuid %q (%s)', member.payload.uuid, member.status)
    elseif member.status ~= 'alive' then
        ret.status = 'unreachable'
        ret.message = string.format('Server status is %q', member.status)
    elseif member.payload.uuid == nil then
        ret.status = 'unconfigured'
        ret.message = member.payload.error or member.payload.warning or ''
    elseif member.payload.error ~= nil then
        ret.status = 'error'
        ret.message = member.payload.error
    elseif member.payload.warning ~= nil then
        ret.status = 'warning'
        ret.message = member.payload.warning
    else
        ret.status = 'healthy'
        ret.message = ''
    end

    if member and member.uri ~= nil then
        members[member.uri] = nil
    end

    return ret
end

local function get_servers_and_replicasets()
    local members = membership.members()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        topology_cfg = {
            servers = {},
            replicasets = {},
        }
    end

    local servers = {}
    local replicasets = {}
    local known_roles = confapplier.get_known_roles()
    local leaders_order = {}

    --- Replicaset general information.
    -- @tfield
    --   string uuid
    --   The replicaset UUID.
    -- @tfield
    --   {string,...}  roles
    --   Roles enabled on the replicaset.
    -- @tfield
    --   string status
    --   Replicaset health.
    -- @tfield
    --   ServerInfo master
    --   Replicaset leader according to configuration.
    -- @tfield
    --   ServerInfo active_master
    --   Active leader.
    -- @tfield
    --   number weight
    --   Vshard replicaset weight. Matters only if vshard-storage role is enabled.
    -- @tfield
    --   {ServerInfo,...} servers
    --   Circular reference to all instances in the replicaset.
    -- @table ReplicasetInfo
    for replicaset_uuid, replicaset in pairs(topology_cfg.replicasets) do
        replicasets[replicaset_uuid] = {
            uuid = replicaset_uuid,
            roles = {},
            status = 'healthy',
            master = nil,
            active_master = nil,
            weight = nil,
            vshard_group = replicaset.vshard_group,
            servers = {},
        }

        local enabled_roles = confapplier.get_enabled_roles(replicaset.roles)

        for _, role in pairs(known_roles) do
            if enabled_roles[role] then
                table.insert(replicasets[replicaset_uuid].roles, role)
            end
        end

        if replicaset.roles['vshard-storage'] then
            replicasets[replicaset_uuid].weight = replicaset.weight or 0.0
        end

        leaders_order[replicaset_uuid] = topology.get_leaders_order(
            topology_cfg.servers,
            replicaset_uuid,
            replicaset.master
        )
    end

    local active_masters = topology.get_active_masters()

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        local srv = get_server_info(members, instance_uuid, server.uri)

        srv.disabled = not topology.not_disabled(instance_uuid, server)
        srv.replicaset = replicasets[server.replicaset_uuid]

        if leaders_order[server.replicaset_uuid][1] == instance_uuid then
            srv.replicaset.master = srv
        end
        if active_masters[server.replicaset_uuid] == instance_uuid then
            srv.replicaset.active_master = srv
        end
        if srv.status ~= 'healthy' then
            srv.replicaset.status = 'unhealthy'
        end

        srv.priority = utils.table_find(
            leaders_order[server.replicaset_uuid],
            instance_uuid
        )
        srv.labels = server.labels or {}
        srv.replicaset.servers[srv.priority] = srv

        servers[instance_uuid] = srv
    end

    for _, m in pairs(members) do
        if (m.status == 'alive') and (m.payload.uuid == nil) then
            table.insert(servers, {
                uri = m.uri,
                uuid = '',
                status = 'unconfigured',
                message = m.payload.error or m.payload.warning or '',
                alias = m.payload.alias
            })
        end
    end

    return servers, replicasets
end

--- Retrieve `box.slab.info` of a remote server.
-- @function get_stat
-- @local
-- @tparam string uri
-- @treturn[1] table
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_stat(uri)
    if uri == nil or uri == membership.myself().uri then
        if type(box.cfg) == 'function' then
            return nil
        end

        local slab_info = box.slab.info()
        return {
            items_size = slab_info.items_size,
            items_used = slab_info.items_used,
            items_used_ratio = slab_info.items_used_ratio,

            quota_size = slab_info.quota_size,
            quota_used = slab_info.quota_used,
            quota_used_ratio = slab_info.quota_used_ratio,

            arena_size = slab_info.arena_size,
            arena_used = slab_info.arena_used,
            arena_used_ratio = slab_info.arena_used_ratio,
        }
    end

    local conn, err = pool.connect(uri)
    if not conn then
        return nil, err
    end

    return errors.netbox_call(
        conn,
        '_G.__cluster_admin_get_stat',
        {}, {timeout = 1}
    )
end

--- Retrieve `box.cfg` and `box.info` of a remote server.
-- @function get_info
-- @local
-- @tparam string uri
-- @treturn[1] table
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_info(uri)
    if uri == nil or uri == membership.myself().uri then
        if type(box.cfg) == 'function' then
            return nil
        end

        local box_cfg = box.cfg
        local box_info = box.info()
        local ret = {
            general = {
                version = box_info.version,
                pid = box_info.pid,
                uptime = box_info.uptime,
                instance_uuid = box_info.uuid,
                replicaset_uuid = box_info.cluster.uuid,
                work_dir = box_cfg.work_dir,
                memtx_dir = box_cfg.memtx_dir,
                vinyl_dir = box_cfg.vinyl_dir,
                wal_dir = box_cfg.wal_dir,
                worker_pool_threads = box_cfg.worker_pool_threads,
                listen = box_cfg.listen and tostring(box_cfg.listen),
                ro = box_info.ro,
            },
            storage = {
                -- wal
                too_long_threshold = box_cfg.too_long_threshold,
                wal_dir_rescan_delay = box_cfg.wal_dir_rescan_delay,
                wal_max_size = box_cfg.wal_max_size,
                wal_mode = box_cfg.wal_mode,
                rows_per_wal = box_cfg.rows_per_wal,
                -- memtx
                memtx_memory = box_cfg.memtx_memory,
                memtx_max_tuple_size = box_cfg.memtx_max_tuple_size,
                memtx_min_tuple_size = box_cfg.memtx_min_tuple_size,
                -- vinyl
                vinyl_bloom_fpr = box_cfg.vinyl_bloom_fpr,
                vinyl_cache = box_cfg.vinyl_cache,
                vinyl_memory = box_cfg.vinyl_memory,
                vinyl_max_tuple_size = box_cfg.vinyl_max_tuple_size,
                vinyl_page_size = box_cfg.vinyl_page_size,
                vinyl_range_size = box_cfg.vinyl_range_size,
                vinyl_run_size_ratio = box_cfg.vinyl_run_size_ratio,
                vinyl_run_count_per_level = box_cfg.vinyl_run_count_per_level,
                vinyl_timeout = box_cfg.vinyl_timeout,
                vinyl_read_threads = box_cfg.vinyl_read_threads,
                vinyl_write_threads = box_cfg.vinyl_write_threads,
            },
            network = {
                net_msg_max = box_cfg.net_msg_max,
                readahead = box_cfg.readahead,
                io_collect_interval = box_cfg.io_collect_interval,
            },
            replication = {
                replication_connect_quorum = box_cfg.replication_connect_quorum,
                replication_connect_timeout = box_cfg.replication_connect_timeout,
                replication_skip_conflict = box_cfg.replication_skip_conflict,
                replication_sync_lag = box_cfg.replication_sync_lag,
                replication_sync_timeout = box_cfg.replication_sync_timeout,
                replication_timeout = box_cfg.replication_timeout,
                vclock = box_info.vclock,
                replication_info = {},
            },
        }

        for i, replica in pairs(box_info.replication) do
            ret.replication.replication_info[i] = {
                id = replica.id,
                lsn = replica.lsn,
                uuid = replica.uuid,
                upstream_status = replica.upstream and replica.upstream.status,
                upstream_message = replica.upstream and replica.upstream.message,
                upstream_idle = replica.upstream and replica.upstream.idle,
                upstream_peer = replica.upstream and replica.upstream.peer,
                upstream_lag = replica.upstream and replica.upstream.lag,
                downstream_status = replica.downstream and replica.downstream.status,
                downstream_message = replica.downstream and replica.downstream.message,
            }
        end

        return ret
    end

    local conn, err = pool.connect(uri)
    if not conn then
        return nil, err
    end

    return errors.netbox_call(
        conn,
        '_G.__cluster_admin_get_info',
        {}, {timeout = 1}
    )
end

--- Get alias, uri and uuid of current instance.
-- @function get_self
-- @local
-- @treturn table
local function get_self()
    local myself = membership.myself()
    local result = {
        alias = myself.payload.alias,
        uri = myself.uri,
        uuid = nil,
    }
    if type(box.cfg) ~= 'function' then
        result.uuid = box.info.uuid
    end
    return result
end

--- Get servers list.
-- Optionally filter out the server with given uuid.
-- @function get_servers
-- @tparam[opt] string uuid
-- @treturn {ServerInfo,...}
local function get_servers(uuid)
    checks('?string')

    local ret = {}
    local servers, _ = get_servers_and_replicasets()
    if uuid then
        table.insert(ret, servers[uuid])
    else
        for _, v in pairs(servers) do
            table.insert(ret, v)
        end
    end
    return ret
end

--- Get replicasets list.
-- Optionally filter out the replicaset with given uuid.
-- @function get_replicasets
-- @tparam[opt] string uuid
-- @treturn {ReplicasetInfo,...}
local function get_replicasets(uuid)
    checks('?string')

    local ret = {}
    local _, replicasets = get_servers_and_replicasets()
    if uuid then
        table.insert(ret, replicasets[uuid])
    else
        for _, v in pairs(replicasets) do
            table.insert(ret, v)
        end
    end
    return ret
end

--- Discover an instance.
-- @function probe_server
-- @tparam string uri
local function probe_server(uri)
    checks('string')
    local ok, err = membership.probe_uri(uri)
    if not ok then
        return nil, e_probe_server:new('Probe %q failed: %s', uri, err)
    end

    return true
end

--- Join an instance to the cluster.
--
-- @function join_server
-- @tparam table args
-- @tparam string args.uri
-- @tparam ?string args.instance_uuid
-- @tparam ?string args.replicaset_uuid
-- @tparam ?{string,...} args.roles
-- @tparam ?number args.timeout
-- @tparam ?{[string]=string,...} args.labels
-- @tparam ?string args.vshard_group
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function join_server(args)
    checks({
        uri = 'string',
        instance_uuid = '?string',
        replicaset_uuid = '?string',
        roles = '?table',
        timeout = '?number',
        labels = '?table',
        vshard_group = '?string',
    })

    if args.instance_uuid == nil then
        args.instance_uuid = uuid_lib.str()
    end

    if args.replicaset_uuid == nil then
        args.replicaset_uuid = uuid_lib.str()
    end

    local labels = args.labels

    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        -- Bootstrapping first instance from the web UI
        local myself = membership.myself()
        if args.uri == myself.uri then
            return package.loaded['cluster'].bootstrap(
                confapplier.get_enabled_roles(args.roles),
                {
                    instance_uuid = args.instance_uuid,
                    replicaset_uuid = args.replicaset_uuid,
                },
                labels, args.vshard_group
            )
        else
            return nil, e_topology_edit:new(
                'Invalid attempt to call join_server().' ..
                ' This instance isn\'t bootstrapped yet' ..
                ' and advertises uri=%q while you are joining uri=%q.',
                myself.uri, args.uri
            )
        end
    end

    local ok, err = probe_server(args.uri)
    if not ok then
        return nil, err
    end

    if topology_cfg.servers[args.instance_uuid] ~= nil then
        return nil, e_topology_edit:new(
            'Server %q is already joined',
            args.instance_uuid
        )
    end

    topology_cfg.servers[args.instance_uuid] = {
        uri = args.uri,
        replicaset_uuid = args.replicaset_uuid,
        labels = labels
    }

    if topology_cfg.replicasets[args.replicaset_uuid] == nil then
        local replicaset = {
            roles = confapplier.get_enabled_roles(args.roles),
            master = {args.instance_uuid},
            weight = 0,
        }

        if replicaset.roles['vshard-storage'] then
            replicaset.vshard_group = args.vshard_group or 'default'
            local vshard_groups = vshard_utils.get_known_groups()
            local group_params = vshard_groups[replicaset.vshard_group]

            if group_params and not group_params.bootstrapped then
                replicaset.weight = 1
            end
        end

        topology_cfg.replicasets[args.replicaset_uuid] = replicaset
    else
        local replicaset = topology_cfg.replicasets[args.replicaset_uuid]
        replicaset.master = topology.get_leaders_order(
            confapplier.get_readonly('topology').servers,
            args.replicaset_uuid,
            replicaset.master
        )
        table.insert(replicaset.master, args.instance_uuid)
    end

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    local timeout = args.timeout or 0
    if not (timeout > 0) then
        return true
    end

    local deadline = fiber.time() + timeout
    local cond = membership.subscribe()
    local conn = nil
    while not conn and fiber.time() < deadline do
        cond:wait(0.2)

        local member = membership.get_member(args.uri)
        if (member ~= nil)
        and (member.status == 'alive')
        and (member.payload.uuid == args.instance_uuid)
        and (member.payload.error == nil)
        and (member.payload.ready)
        then
            conn = pool.connect(args.uri)
        end
    end
    membership.unsubscribe(cond)

    if conn then
        return true
    else
        return nil, e_topology_edit:new('Timeout connecting %q', args.uri)
    end
end

--- Edit an instance.
--
-- @function edit_server
-- @local
-- @tparam table args
-- @tparam string args.uuid
-- @tparam ?string args.uri
-- @tparam ?{[string]=string,...} args.labels
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_server(args)
    checks({
        uuid = 'string',
        uri = '?string',
        labels = '?table'
    })

    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, e_topology_edit:new('Not bootstrapped yet')
    end

    if topology_cfg.servers[args.uuid] == nil then
        return nil, e_topology_edit:new('Server %q not in config', args.uuid)
    elseif topology_cfg.servers[args.uuid] == "expelled" then
        return nil, e_topology_edit:new('Server %q is expelled', args.uuid)
    end

    if args.uri ~= nil then
        topology_cfg.servers[args.uuid].uri = args.uri
    end
    if args.labels ~= nil then
        topology_cfg.servers[args.uuid].labels = args.labels
    end

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

--- Expel an instance.
-- Forever.
--
-- @function expel_server
-- @tparam string uuid
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function expel_server(uuid)
    checks('string')

    local topology_cfg = confapplier.get_deepcopy('topology')

    if topology_cfg.servers[uuid] == nil then
        return nil, e_topology_edit:new('Server %q not in config', uuid)
    elseif topology_cfg.servers[uuid] == "expelled" then
        return nil, e_topology_edit:new('Server %q is already expelled', uuid)
    end

    local replicaset_uuid = topology_cfg.servers[uuid].replicaset_uuid
    local replicaset = topology_cfg.replicasets[replicaset_uuid]

    topology_cfg.servers[uuid] = "expelled"

    for _it, _, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        if server.replicaset_uuid == replicaset_uuid then
            replicaset_uuid = nil
        end
    end

    if replicaset_uuid ~= nil then
        topology_cfg.replicasets[replicaset_uuid] = nil
        -- luacheck: ignore replicaset
        replicaset = nil
    else
        local master_pos
        if type(replicaset.master) == 'string' and replicaset.master == uuid then
            master_pos = 1
        elseif type(replicaset.master) == 'table' then
            master_pos = utils.table_find(replicaset.master, uuid)
        end

        if master_pos == 1 then
            return nil, e_topology_edit:new(
                'Server %q is the master and can\'t be expelled', uuid
            )
        elseif master_pos ~= nil then
            table.remove(replicaset.master, master_pos)
        end
    end

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

local function set_servers_disabled_state(uuids, state)
    checks('table', 'boolean')
    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, e_topology_edit:new('Not bootstrapped yet')
    end

    for _, uuid in pairs(uuids) do
        if topology_cfg.servers[uuid] == nil then
            return nil, e_topology_edit:new('Server %q not in config', uuid)
        elseif topology_cfg.servers[uuid] == "expelled" then
            return nil, e_topology_edit:new('Server %q is already expelled', uuid)
        end

        topology_cfg.servers[uuid].disabled = state
    end

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return get_servers()
end

--- Enable nodes after they were disabled.
-- @function enable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function enable_servers(uuids)
    checks('table')
    return set_servers_disabled_state(uuids, false)
end

--- Temporarily diable nodes.
--
-- @function disable_servers
-- @tparam {string,...} uuids
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function disable_servers(uuids)
    checks('table')
    return set_servers_disabled_state(uuids, true)
end

--- Edit replicaset parameters.
-- @function edit_replicaset
-- @tparam table args
-- @tparam string args.uuid
-- @tparam ?{string,...} args.roles
-- @tparam ?{string,...} args.master Failover order
-- @tparam ?number args.weight
-- @tparam ?string args.vshard_group
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_replicaset(args)
    args = args or {}
    checks({
        uuid = 'string',
        roles = '?table',
        master = '?string|table',
        weight = '?number',
        vshard_group = '?string',
    })

    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, e_topology_edit:new('Not bootstrapped yet')
    end

    local replicaset = topology_cfg.replicasets[args.uuid]

    if replicaset == nil then
        return nil, e_topology_edit:new('Replicaset %q not in config', args.uuid)
    end

    if args.roles ~= nil then
        replicaset.roles = confapplier.get_enabled_roles(args.roles)
    end

    if args.master ~= nil then
        replicaset.master = topology.get_leaders_order(
            confapplier.get_readonly('topology').servers,
            args.uuid,
            args.master
        )
    end

    -- Set proper vshard_group
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            -- ignore unless replicaset is a storage
            break
        end

        if args.vshard_group ~= nil then
            replicaset.vshard_group = args.vshard_group
            break
        end

        replicaset.vshard_group = 'default'
    until true

    -- Set proper replicaset weight
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            replicaset.weight = 0
            break
        end

        if args.weight ~= nil then
            replicaset.weight = args.weight
            break
        end

        local vshard_groups = vshard_utils.get_known_groups()
        local group_params = vshard_groups[replicaset.vshard_group or 'default']

        if group_params and not group_params.bootstrapped then
            replicaset.weight = 1
        end
    until true

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

--- Get current failover state.
-- @function get_failover_enabled
local function get_failover_enabled()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return false
    end
    return topology_cfg.failover or false
end

--- Enable or disable automatic failover.
-- @function set_failover_enabled
-- @tparam boolean enabled
-- @treturn[1] boolean New failover state
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_failover_enabled(enabled)
    checks('boolean')
    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, e_topology_edit:new('Not bootstrapped yet')
    end
    topology_cfg.failover = enabled

    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return topology_cfg.failover
end

_G.__cluster_admin_get_stat = get_stat
_G.__cluster_admin_get_info = get_info

return {
    get_stat = get_stat,
    get_info = get_info,
    get_self = get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,

    probe_server = probe_server,
    join_server = join_server,
    edit_server = edit_server,
    expel_server = expel_server,
    enable_servers = enable_servers,
    disable_servers = disable_servers,

    edit_replicaset = edit_replicaset,

    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,

    --- Call `vshard.router.bootstrap()`.
    -- This function distributes all buckets across the replica sets.
    -- @function bootstrap
    -- @treturn[1] boolean `true`
    -- @treturn[2] nil
    -- @treturn[2] table Error description
    bootstrap_vshard = function()
        return rpc.call('vshard-router', 'bootstrap')
    end,
}
