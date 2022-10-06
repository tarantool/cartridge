local modul_name = 'cartridge.lua-api.compression'
local log = require('log')

local function get_cluster_compression_info()
    --local box_cfg = box.cfg
    log.warn('<<<<<<<<<<<<<<<<<<<<<<<<')
    log.warn('<<<<<<<<<<<<<<<<<<<<<<<<')

    local box_info = box.info()

    for i = 1, table.maxn(box_info.replication) do
        local replica = box_info.replication[i]
        log.warn(replica)
        --ret.replication.replication_info[i] = replica and {
        --    id = replica.id,
        --    lsn = replica.lsn,
        --    uuid = replica.uuid,
        --    upstream_status = replica.upstream and replica.upstream.status,
        --    upstream_message = replica.upstream and replica.upstream.message,
        --    upstream_idle = replica.upstream and replica.upstream.idle,
        --    upstream_peer = replica.upstream and replica.upstream.peer,
        --    upstream_lag = replica.upstream and replica.upstream.lag,
        --    downstream_status = replica.downstream and replica.downstream.status,
        --    downstream_message = replica.downstream and replica.downstream.message,
        --    downstream_lag = replica.downstream and replica.downstream.lag,
        --} or box.NULL
    end
    log.warn('>>>>>>>>>>>>>>>>>>>>>>>>>>')
    log.warn('>>>>>>>>>>>>>>>>>>>>>>>>>>')
    return {
        cluster_id = '000000qwe',
    }
end

return {
    get_cluster_compression_info = get_cluster_compression_info,
}
