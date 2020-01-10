#!/usr/bin/env tarantool
-- luacheck: ignore _it

--- Administration functions.
--
-- @module cartridge.admin

local fun = require('fun')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local uuid_lib = require('uuid')
local membership = require('membership')

local rpc = require('cartridge.rpc')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local roles = require('cartridge.roles')
local failover = require('cartridge.failover')
local topology = require('cartridge.topology')
local twophase = require('cartridge.twophase')
local vshard_utils = require('cartridge.vshard-utils')
local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')

local EditTopologyError = errors.new_class('Editing cluster topology failed')
local ProbeServerError = errors.new_class('ProbeServerError')

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
    -- @tfield
    --   number clock_delta
    --   Difference between remote clock and the current one (in
    --   seconds), obtained from the membership module (SWIM protocol).
    --   Positive values mean remote clock are ahead of local, and vice
    --   versa.
    -- @table ServerInfo
    local ret = {
        alias = alias,
        uri = uri,
        uuid = uuid,
        clock_delta = nil,
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
        ret.message = member.payload.state or ''
    elseif member.payload.state == 'ConfiguringRoles'
    or member.payload.state == 'RolesConfigured' then
        ret.status = 'healthy'
        ret.message = ''
    elseif member.payload.state == 'InitError'
    or member.payload.state == 'BootError'
    or member.payload.state == 'OperationError' then
        ret.status = 'error'
        ret.message = member.payload.state
    else
        ret.status = 'warning'
        ret.message = member.payload.state or 'UnknownState'
    end

    if member and member.status == 'alive' and member.clock_delta ~= nil then
        ret.clock_delta = member.clock_delta * 1e-6
    end

    if member and member.uri ~= nil then
        members[member.uri] = nil
    end

    return ret
end

local function get_topology()
    local state, err = confapplier.get_state()
    -- OperationError doesn't influence observing topology
    if state == 'InitError' or state == 'BootError' then
        return nil, err
    end

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
    local known_roles = roles.get_known_roles()
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
    --   Vshard replicaset weight.
    --   Matters only if vshard-storage role is enabled.
    -- @tfield
    --   string vshard_group
    --   Name of vshard group the replicaset belongs to.
    -- @tfield
    --   boolean all_rw
    --   A flag indicating that all servers in the replicaset should be read-write.
    -- @tfield
    --   string alias
    --   Human-readable replicaset name.
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
            all_rw = replicaset.all_rw or false,
            alias = replicaset.alias or 'unnamed',
        }

        local enabled_roles = roles.get_enabled_roles(replicaset.roles)

        for _, role in pairs(known_roles) do
            if enabled_roles[role] then
                table.insert(replicasets[replicaset_uuid].roles, role)
            end
        end

        if replicaset.roles['vshard-storage'] then
            replicasets[replicaset_uuid].weight = replicaset.weight or 0.0
        end

        leaders_order[replicaset_uuid] = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )
    end

    local active_leaders = failover.get_active_leaders()

    for _it, instance_uuid, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
        local srv = get_server_info(members, instance_uuid, server.uri)

        srv.disabled = not topology.not_disabled(instance_uuid, server)
        srv.replicaset = replicasets[server.replicaset_uuid]

        if leaders_order[server.replicaset_uuid][1] == instance_uuid then
            srv.replicaset.master = srv
        end
        if active_leaders[server.replicaset_uuid] == instance_uuid then
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
                clock_delta = m.clock_delta and (m.clock_delta * 1e-6),
                alias = m.payload.alias,
            })
        end
    end

    return {
        servers = servers,
        replicasets = replicasets,
    }
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

        local vshard_buckets_count
        if service_registry.get('vshard-storage') then
            vshard_buckets_count = _G.vshard.storage.buckets_count()
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

            vshard_buckets_count = vshard_buckets_count,
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
    local state, err = confapplier.get_state()
    local result = {
        uri = myself.uri,
        uuid = confapplier.get_instance_uuid(),
        demo_uri = os.getenv('TARANTOOL_DEMO_URI'),
        alias = myself.payload.alias,
        state = state,
        error = err and err.err or nil,
    }
    return result
end

--- Get servers list.
-- Optionally filter out the server with the given uuid.
-- @function get_servers
-- @tparam[opt] string uuid
-- @treturn[1] {ServerInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_servers(uuid)
    checks('?string')

    local ret = {}
    local topology, err = get_topology()
    if topology == nil then
        return nil, err
    end

    if uuid then
        table.insert(ret, topology.servers[uuid])
    else
        for _, v in pairs(topology.servers) do
            table.insert(ret, v)
        end
    end
    return ret
end

--- Get replicasets list.
-- Optionally filter out the replicaset with given uuid.
-- @function get_replicasets
-- @tparam[opt] string uuid
-- @treturn[1] {ReplicasetInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_replicasets(uuid)
    checks('?string')

    local ret = {}
    local topology, err = get_topology()
    if topology == nil then
        return nil, err
    end

    if uuid then
        table.insert(ret, topology.replicasets[uuid])
    else
        for _, v in pairs(topology.replicasets) do
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
        return nil, ProbeServerError:new('Probe %q failed: %s', uri, err)
    end

    return true
end

local topology_cfg_checker = {
    auth = '?',
    failover = '?',
    servers = 'table',
    replicasets = 'table',
}

local function __join_server(topology_cfg, params)
    checks(topology_cfg_checker, {
        uri = 'string',
        uuid = 'string',
        labels = '?table',
        replicaset_uuid = 'string',
    })

    if topology_cfg.servers[params.uuid] ~= nil then
        return nil, EditTopologyError:new(
            "Server %q is already joined",
            params.uuid
        )
    end

    local replicaset = topology_cfg.replicasets[params.replicaset_uuid]

    replicaset.master = topology.get_leaders_order(
        topology_cfg, params.replicaset_uuid
    )
    table.insert(replicaset.master, params.uuid)

    local server = {
        uri = params.uri,
        labels = params.labels,
        disabled = false,
        replicaset_uuid = params.replicaset_uuid,
    }

    topology_cfg.servers[params.uuid] = server
    return true
end

local function __edit_server(topology_cfg, params)
    checks(topology_cfg_checker, {
        uuid = 'string',
        uri = '?string',
        labels = '?table',
        disabled = '?boolean',
        expelled = '?boolean',
    })

    local server = topology_cfg.servers[params.uuid]
    if server == nil then
        return nil, EditTopologyError:new('Server %q not in config', params.uuid)
    elseif server == "expelled" then
        return nil, EditTopologyError:new('Server %q is expelled', params.uuid)
    end

    if params.uri ~= nil then
        server.uri = params.uri
    end

    if params.labels ~= nil then
        server.labels = params.labels
    end

    if params.disabled ~= nil then
        server.disabled = params.disabled
    end

    if params.expelled == true then
        topology_cfg.servers[params.uuid] = 'expelled'
    end

    return true
end

local function __edit_replicaset(topology_cfg, params)
    checks(topology_cfg_checker, {
        uuid = 'string',
        alias = '?string',
        all_rw = '?boolean',
        roles = '?table',
        weight = '?number',
        failover_priority = '?table',
        vshard_group = '?string',
        join_servers = '?table',
    })

    local replicaset = topology_cfg.replicasets[params.uuid]

    if replicaset == nil then
        if params.join_servers == nil
        or next(params.join_servers) == nil
        then
            return nil, EditTopologyError:new(
                'Replicaset %q not in config',
                params.uuid
            )
        end

        replicaset = {
            roles = {},
            alias = 'unnamed',
            master = {},
            weight = 0,
        }
        topology_cfg.replicasets[params.uuid] = replicaset
    end

    if params.join_servers ~= nil then
        for _, srv in pairs(params.join_servers) do
            if srv.uuid == nil then
                srv.uuid = uuid_lib.str()
            end

            srv.replicaset_uuid = params.uuid

            local ok, err = __join_server(topology_cfg, srv)
            if ok == nil then
                return nil, err
            end
        end
    end

    local old_roles = replicaset.roles
    if params.roles ~= nil then
        replicaset.roles = roles.get_enabled_roles(params.roles)
    end

    if params.failover_priority ~= nil then
        replicaset.master = topology.get_leaders_order(
            topology_cfg, params.uuid,
            params.failover_priority
        )
    end

    if params.alias ~= nil then
        replicaset.alias = params.alias
    end

    if params.all_rw ~= nil then
        replicaset.all_rw = params.all_rw
    end

    -- Set proper vshard group
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            -- ignore unless replicaset is a storage
            break
        end

        if params.vshard_group ~= nil then
            replicaset.vshard_group = params.vshard_group
            break
        end

        if replicaset.vshard_group == nil then
            replicaset.vshard_group = 'default'
        end
    until true


    -- Set proper replicaset weight
    repeat -- until true
        if not replicaset.roles['vshard-storage'] then
            replicaset.weight = 0
            break
        end

        if params.weight ~= nil then
            replicaset.weight = params.weight
            break
        end

        if old_roles['vshard-storage'] then
            -- don't adjust weight if storage role
            -- has already been enabled
            break
        end

        local vshard_groups = vshard_utils.get_known_groups()
        local group_params = vshard_groups[replicaset.vshard_group]

        if group_params and not group_params.bootstrapped then
            replicaset.weight = 1
        else
            replicaset.weight = 0
        end
    until true

    return true
end

--- Edit cluster topology.
-- This function can be used for:
--
-- - bootstrapping cluster from scratch
-- - joining a server to an existing replicaset
-- - creating new replicaset with one or more servers
-- - editing uri/labels of servers
-- - disabling and expelling servers
--
-- (**Added** in v1.0.0-17)
-- @function edit_topology
-- @tparam table args
-- @tparam ?{EditServerParams,..} args.servers
-- @tparam ?{EditReplicasetParams,..} args.replicasets
-- @within Editing topology

--- Replicatets modifications.
-- @tfield ?string uuid
-- @tfield ?string alias
-- @tfield ?{string,...} roles
-- @tfield ?boolean all_rw
-- @tfield ?number weight
-- @tfield ?{string,...} failover_priority
--   array of uuids specifying servers failover priority
-- @tfield ?string vshard_group
-- @tfield ?{JoinServerParams,...} join_servers
-- @table EditReplicasetParams
-- @within Editing topology

--- Parameters required for joining a new server.
-- @tfield string uri
-- @tfield ?string uuid
-- @tfield ?table labels
-- @table JoinServerParams
-- @within Editing topology

--- Servers modifications.
-- @tfield ?string uri
-- @tfield string uuid
-- @tfield ?table labels
-- @tfield ?boolean disabled
-- @tfield ?boolean expelled
--   Expelling an instance is permanent and can't be undone.
--   It's suitable for situations when the hardware is destroyed,
--   snapshots are lost and there is no hope to bring it back to life.
-- @table EditServerParams
-- @within Editing topology

local function edit_topology(args)
    checks({
        replicasets = '?table',
        servers = '?table',
    })

    local args = table.deepcopy(args)
    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        topology_cfg = {
            replicasets = {},
            servers = {},
            failover = false,
        }
    end

    local i = 0
    for _, srv in pairs(args.servers or {}) do
        i = i + 1
        if args.servers[i] == nil then
            error('bad argument args.servers' ..
                ' to edit_topology (it must be a contiguous array)', 2
            )
        end

        local ok, err = __edit_server(topology_cfg, srv)
        if ok == nil then
            return nil, err
        end
    end

    local i = 0
    for _, rpl in pairs(args.replicasets or {}) do
        i = i + 1
        if args.replicasets[i] == nil then
            error('bad argument args.replicasets' ..
                ' to edit_topology (it must be a contiguous array)', 2
            )
        end

        if rpl.uuid == nil then
            rpl.uuid = uuid_lib.str()
        end

        local ok, err = __edit_replicaset(topology_cfg, rpl)
        if ok == nil then
            return nil, err
        end
    end

    for replicaset_uuid, _ in pairs(topology_cfg.replicasets) do
        local replicaset_empty = true
        for _it, _, server in fun.filter(topology.not_expelled, topology_cfg.servers) do
            if server.replicaset_uuid == replicaset_uuid then
                replicaset_empty = false
            end
        end

        if replicaset_empty then
            topology_cfg.replicasets[replicaset_uuid] = nil
        else
            local replicaset = topology_cfg.replicasets[replicaset_uuid]
            local leaders = topology.get_leaders_order(topology_cfg, replicaset_uuid)

            if topology_cfg.servers[leaders[1]] == 'expelled' then
                return nil, EditTopologyError:new(
                    "Server %q is the leader and can't be expelled", leaders[1]
                )
            end

            -- filter out all expelled instances
            replicaset.master = {}
            for _, leader_uuid in pairs(leaders) do
                if topology.not_expelled(leader_uuid, topology_cfg.servers[leader_uuid]) then
                    table.insert(replicaset.master, leader_uuid)
                end
            end
        end
    end

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    local ret = {
        replicasets = {},
        servers = {},
    }

    local topology, err = get_topology()
    if topology == nil then
        return nil, err
    end

    for _, srv in pairs(args.servers or {}) do
        table.insert(ret.servers, topology.servers[srv.uuid])
    end

    for _, rpl in pairs(args.replicasets or {}) do
        for _, srv in pairs(rpl.join_servers or {}) do
            table.insert(ret.servers, topology.servers[srv.uuid])
        end
        table.insert(ret.replicasets, topology.replicasets[rpl.uuid])
    end

    return ret
end

--- Join an instance to the cluster (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function join_server
-- @within Deprecated functions
-- @tparam table args
-- @tparam string args.uri
-- @tparam ?string args.instance_uuid
-- @tparam ?string args.replicaset_uuid
-- @tparam ?{string,...} args.roles
-- @tparam ?number args.timeout
-- @tparam ?{[string]=string,...} args.labels
-- @tparam ?string args.vshard_group
-- @tparam ?string args.replicaset_alias
-- @tparam ?number args.replicaset_weight
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
        replicaset_alias = '?string',
        replicaset_weight = '?number',
    })

    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        -- Bootstrapping first instance from the web UI
        local myself = membership.myself()
        if args.uri ~= myself.uri then
            return nil, EditTopologyError:new(
                "Invalid attempt to call join_server()." ..
                " This instance isn't bootstrapped yet" ..
                " and advertises uri=%q while you are joining uri=%q.",
                myself.uri, args.uri
            )
        end
    end

    if topology_cfg ~= nil
    and topology_cfg.replicasets[args.replicaset_uuid] ~= nil
    then
        -- Keep old behavior:
        -- Prevent simultaneous join_server and edit_replicaset
        -- Ignore roles if replicaset already exists
        args.roles = nil
        args.vshard_group = nil
        args.replicaset_alias = nil
        args.replicaset_weight = nil
    end


    local topology, err = edit_topology({
        -- async = false,
        replicasets = {{
            uuid = args.replicaset_uuid,
            roles = args.roles,
            alias = args.replicaset_alias,
            weight = args.replicaset_weight,
            vshard_group = args.vshard_group,
            join_servers = {{
                uri = args.uri,
                uuid = args.instance_uuid,
                labels = args.labels,
            }}
        }}
    })

    if topology == nil then
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
        and (
            member.payload.state == 'ConfiguringRoles' or
            member.payload.state == 'RolesConfigured'
        ) then
            conn = pool.connect(args.uri)
        end
    end
    membership.unsubscribe(cond)

    if conn then
        return true
    else
        return nil, EditTopologyError:new('Timeout connecting %q', args.uri)
    end
end

--- Edit an instance (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function edit_server
-- @within Deprecated functions
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

    local topology, err = edit_topology({
        servers = {args},
    })
    if topology == nil then
        return nil, err
    end

    return true
end

--- Expel an instance (*deprecated*).
-- Forever.
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function expel_server
-- @within Deprecated functions
-- @tparam string uuid
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function expel_server(uuid)
    checks('string')

    local topology, err = edit_topology({
        servers = {{
            uuid = uuid,
            expelled = true,
        }}
    })

    if topology == nil then
        return nil, err
    end

    return true
end

local function set_servers_disabled_state(uuids, state)
    checks('table', 'boolean')
    local patch = {servers = {}}

    for _, uuid in pairs(uuids) do
        table.insert(patch.servers, {
            uuid = uuid,
            disabled = state,
        })
    end

    local topology, err = edit_topology(patch)
    if topology == nil then
        return nil, err
    end

    return topology.servers
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

--- Edit replicaset parameters (*deprecated*).
--
-- (**Deprecated** since v1.0.0-17 in favor of `cartridge.admin_edit_topology`)
--
-- @function edit_replicaset
-- @within Deprecated functions
-- @tparam table args
-- @tparam string args.uuid
-- @tparam string args.alias
-- @tparam ?{string,...} args.roles
-- @tparam ?{string,...} args.master Failover order
-- @tparam ?number args.weight
-- @tparam ?string args.vshard_group
-- @tparam ?boolean args.all_rw
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_replicaset(args)
    checks({
        uuid = 'string',
        alias = '?string',
        roles = '?table',
        master = '?table',
        weight = '?number',
        vshard_group = '?string',
        all_rw = '?boolean',
    })

    local topology, err = edit_topology({
        replicasets = {{
            uuid = args.uuid,
            alias = args.alias,
            all_rw = args.all_rw,
            roles = args.roles,
            weight = args.weight,
            failover_priority = args.master,
            vshard_group = args.vshard_group,
        }}
    })

    if topology == nil then
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
        return nil, EditTopologyError:new('Not bootstrapped yet')
    end
    topology_cfg.failover = enabled

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
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

    edit_topology = edit_topology,
    probe_server = probe_server,
    enable_servers = enable_servers,
    disable_servers = disable_servers,

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

    edit_replicaset = edit_replicaset, -- deprecated
    edit_server = edit_server, -- deprecated
    join_server = join_server, -- deprecated
    expel_server = expel_server, -- deprecated
}
