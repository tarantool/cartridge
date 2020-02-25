--- Administration functions (`box.info` related).
--
-- @module cartridge.lua-api.boxinfo
-- @local

local json = require('json')
local errors = require('errors')

local pool = require('cartridge.pool')
local confapplier = require('cartridge.confapplier')

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
            cartridge = {
                version = require('cartridge').VERSION,
                state = server_state,
                error = server_error,
            }
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

_G.__cluster_admin_get_info = get_info

return {
    get_info = get_info,
}
