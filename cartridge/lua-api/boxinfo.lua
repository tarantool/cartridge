--- Administration functions (`box.info` related).
--
-- @module cartridge.lua-api.boxinfo
-- @local

local json = require('json')
local errors = require('errors')

local pool = require('cartridge.pool')
local confapplier = require('cartridge.confapplier')
local vars = require('cartridge.vars').new('cartridge.boxinfo')

vars:new('webui_prefix', nil)
vars:new('http_host', nil)
vars:new('http_port', nil)

local function set_webui_prefix(prefix)
    vars.webui_prefix = prefix
end

--- Retrieve `box.cfg` and `box.info` of a remote server.
-- @function get_info
-- @local
-- @tparam string uri
-- @treturn[1] table
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_info(uri)
    if uri == nil or uri == confapplier.get_advertise_uri() then
        if type(box.cfg) == 'function' then
            return nil
        end

        local box_cfg = box.cfg
        local box_info = box.info()

        local server_state, err = confapplier.get_state()
        local server_error
        if err ~= nil then
            server_error = {
                message = err.err,
                class_name = err.class_name,
                stack = err.stack,
            }

            if type(err.err) ~= 'string' then
                server_error.message = json.encode(err.err)
            end
        end

        local membership_myself = require('membership').myself()
        local membership_options = require('membership.options')

        local vshard, vshard_version, ddl_version
        if package.loaded['vshard-ee'] ~= nil then
            vshard = package.loaded['vshard-ee']
            vshard_version = vshard._VERSION .. ' EE'
        elseif package.loaded['vshard'] ~= nil then
            vshard = package.loaded.vshard
            vshard_version = vshard._VERSION
        end

        if package.loaded['ddl-ee'] ~= nil then
            ddl_version = require('ddl-ee.version') .. ' EE'
        elseif package.loaded['vshard'] ~= nil then
            ddl_version = require('ddl.version')
        end

        local routers = vshard and vshard.router.internal.routers or {}
        local router_info = {}
        if next(routers) ~= nil then
            for group, router in pairs(routers) do
                local info = router:info()
                if group == '_static_router' then
                    group = 'default'
                end
                table.insert(router_info, {
                    vshard_group = group,
                    buckets_available_ro = info.bucket.available_ro,
                    buckets_available_rw = info.bucket.available_rw,
                    buckets_unreachable = info.bucket.unreachable,
                    buckets_unknown = info.bucket.unknown,
                })

            end
        else
            router_info = box.NULL
        end

        local topology_cfg = confapplier.get_readonly('topology')
        local rs_uuid = box_info.cluster.uuid
        local vshard_group = topology_cfg.replicasets[rs_uuid].vshard_group or 'default'
        local ok, storage_info = pcall(vshard and vshard.storage.info)
        local rebalancer_enabled = vshard and vshard.storage and
            vshard.storage.internal.rebalancer_fiber ~= nil
        if ok then
            storage_info = {
                vshard_group = vshard_group,
                buckets_receiving = storage_info.bucket.receiving,
                buckets_active = storage_info.bucket.active,
                buckets_total = storage_info.bucket.total,
                buckets_garbage = storage_info.bucket.garbage,
                buckets_pinned = storage_info.bucket.pinned,
                buckets_sending = storage_info.bucket.sending,
                rebalancer_enabled = rebalancer_enabled,
            }
        else
            storage_info = box.NULL
        end

        if vars.http_port == nil then
            local httpd = package.loaded.cartridge.service_get('httpd')
            local srv_name = {}

            if httpd ~= nil then
                srv_name = httpd.tcp_server:name()
            else
                vars.webui_prefix = nil
            end

            vars.http_host = srv_name.host
            vars.http_port = srv_name.port
        end

        local ok, app_version = pcall(require, 'VERSION')
        if not ok then
            app_version = box.NULL
        end

        local package = require('tarantool').package

        local listen
        if type(box_cfg.listen) ~= "table" then
            listen = box_cfg.listen and tostring(box_cfg.listen)
        else
            listen = box_cfg.listen.uri or box_cfg.listen[1].uri
        end

        local ret = {
            general = {
                version = (package and (package .. ' ') or '') .. box_info.version,
                app_version = app_version,
                pid = box_info.pid,
                uptime = box_info.uptime,
                instance_uuid = box_info.uuid,
                replicaset_uuid = box_info.cluster.uuid,
                work_dir = box_cfg.work_dir,
                memtx_dir = box_cfg.memtx_dir,
                vinyl_dir = box_cfg.vinyl_dir,
                wal_dir = box_cfg.wal_dir,
                worker_pool_threads = box_cfg.worker_pool_threads,
                listen = listen,
                http_host = vars.http_host,
                http_port = vars.http_port,
                webui_prefix = vars.webui_prefix,
                ro = box_info.ro,
                ro_reason = box_info.ro_reason,
                election_state = box_info.election and box_info.election.state,
                election_leader_idle = box_info.election and box_info.election.leader_idle,
                election_mode = box.cfg.election_mode or "off",
                synchro_queue_owner = box_info.synchro and box_info.synchro.queue.owner or 0,
            },
            storage = {
                -- wal
                too_long_threshold = box_cfg.too_long_threshold,
                wal_dir_rescan_delay = box_cfg.wal_dir_rescan_delay,
                wal_max_size = box_cfg.wal_max_size,
                wal_queue_max_size = box_cfg.wal_queue_max_size,
                wal_cleanup_delay = box_cfg.wal_cleanup_delay,
                wal_mode = box_cfg.wal_mode,
                rows_per_wal = box_cfg.rows_per_wal,
                -- memtx
                memtx_memory = box_cfg.memtx_memory,
                memtx_allocator = box_cfg.memtx_allocator,
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
                replication_threads = box_cfg.replication_threads,
                vclock = box_info.vclock,
                replication_info = {},
            },
            cartridge = {
                version = require('cartridge').VERSION,
                vshard_version = vshard_version,
                ddl_version = ddl_version,
                state = server_state,
                error = server_error,
            },
            membership = {
                status = membership_myself.status,
                incarnation = membership_myself.incarnation,
                PROTOCOL_PERIOD_SECONDS = membership_options.PROTOCOL_PERIOD_SECONDS,
                ACK_TIMEOUT_SECONDS = membership_options.ACK_TIMEOUT_SECONDS,
                ANTI_ENTROPY_PERIOD_SECONDS = membership_options.ANTI_ENTROPY_PERIOD_SECONDS,
                SUSPECT_TIMEOUT_SECONDS = membership_options.SUSPECT_TIMEOUT_SECONDS,
                NUM_FAILURE_DETECTION_SUBGROUPS = membership_options.NUM_FAILURE_DETECTION_SUBGROUPS,
            },
            vshard_router = router_info,
            vshard_storage = storage_info,
        }

        for i = 1, table.maxn(box_info.replication) do
            local replica = box_info.replication[i]
            ret.replication.replication_info[i] = replica and {
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
                downstream_lag = replica.downstream and replica.downstream.lag,
            } or box.NULL
        end

        return ret
    end

    local conn, err = pool.connect(uri, {wait_connected = false})
    if not conn then
        return nil, err
    end

    return errors.netbox_call(
        conn, '_G.__cluster_admin_get_info',
        nil, {timeout = 1}
    )
end

_G.__cluster_admin_get_info = get_info

return {
    get_info = get_info,

    set_webui_prefix = set_webui_prefix,
}
