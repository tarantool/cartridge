--- Administration functions (`box.slab.info` related).
--
-- @module cartridge.lua-api.stat
-- @local

local errors = require('errors')

local pool = require('cartridge.pool')
local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')

--- Retrieve `box.slab.info` of a remote server.
-- @function get_stat
-- @local
-- @tparam string uri
-- @treturn[1] table
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_stat(uri)
    if uri == nil or uri == confapplier.get_advertise_uri() then
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

_G.__cluster_admin_get_stat = get_stat

return {
    get_stat = get_stat,
}
