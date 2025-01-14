--- Compression API.
--
-- @module cartridge.lua-api.compression
local lua_api_get_topology = require('cartridge.lua-api.get-topology')
local log = require('log')
local fiber = require('fiber')
local clock = require('clock')

local pool = require('cartridge.pool')
local errors = require('errors')
local vars = require('cartridge.vars').new('cartridge.compression')

vars:new('timeout', 3000)

--- This function gets compression info on cluster aggregated by instances.
-- Function surfs by replicates to find master storages and calls on them __cartridgeGetStorageCompressionInfo() func.
-- @function get_cluster_compression_info
-- @treturn[1] table {{instance_id, instance_compression_info},...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_cluster_compression_info()
    local replicasets, err = lua_api_get_topology.get_replicasets()
    if replicasets == nil then
        return nil, err
    end

    local compression_info = {}

    for _, rpl in pairs(replicasets or {}) do
        for _, role in pairs(rpl.roles or {}) do
            if role == 'vshard-storage' then
                local master = rpl.master

                local conn, err = pool.connect(master.uri, {wait_connected = true, fetch_schema = false})
                if not conn or err ~= nil then
                    if err ~= nil then
                        log.error(err)
                    end
                    table.insert(compression_info, {
                        instance_id = master.uuid,
                        instance_compression_info = {}
                    })
                    goto continue
                end

                local storage_compression_info, err = errors.netbox_call(
                    conn,
                    '_G.__cartridgeGetStorageCompressionInfo', {master}, {timeout = vars.timeout}
                )

                if storage_compression_info == nil or err ~= nil then
                    if err ~= nil then
                        log.error(err)
                    end
                    table.insert(compression_info, {
                        instance_id = master.uuid,
                        instance_compression_info = {}
                    })
                    goto continue
                end

                table.insert(compression_info, {
                    instance_id = master.uuid,
                    instance_compression_info = storage_compression_info[1]})
            end
            ::continue::
        end
    end

    return {
        compression_info = compression_info,
    }, nil
end

--- This function creates temporary space.
-- @function create_tmp_space
-- @local
-- @tparam string space_name
-- @tparam string space_type
-- @tparam table orig_index
-- @tparam string orig_format
-- @tparam string field_format
-- @treturn table
local function create_tmp_space(space_name, space_type, orig_index, orig_format, field_format)
    if space_type == '' then
        error('need suffix for space name')
    end
    local tmp_space_name = '_'..space_name..space_type
    if box.space[tmp_space_name] ~= nil then
        box.space[tmp_space_name]:drop()
    end

    local index_format = {}
    local index_parts = {}
    for index_part_key, index_part in pairs(orig_index.parts) do
        table.insert(index_format, orig_format[index_part.fieldno])
        table.insert(index_parts, {
            field = index_part_key,
            type = index_part.type,
        })
    end

    local space_format = {}
    for _, f in pairs(index_format) do
        table.insert(space_format, f)
    end
    if field_format ~= nil then
        table.insert(space_format, field_format)
    end

    local space = box.schema.create_space(tmp_space_name, {
        temporary = true,
        format = space_format,
        if_not_exists = true,
    })

    space:create_index(orig_index.name, {
        unique = orig_index.unique,
        type = orig_index.type,
        parts = index_parts,
    })

    return space
end

--- This function finds all user spaces with correct schema and index and calculates compression for their fields.
-- @function __cartridgeGetStorageCompressionInfo
-- @treturn[1] table {{space_name, fields_be_compressed},...}
-- @treturn[2] nil
-- @treturn[2] table Error description
function _G.__cartridgeGetStorageCompressionInfo(_)
    local storage_compression_info = {}

    for _, space_info in box.space._space:pairs() do
        local space_info_name_pos = 3
        local space_name = space_info[space_info_name_pos]

        local space_compression_info = {}
        if not space_name:startswith("_") then
            local space = box.space[space_name]
            local space_format = space:format()

            if (space.index == nil) or (next(space_format) == nil) then
                break
            end

            local unique_index = space.index[0]

            for fieldno, field_format in pairs(space_format) do
                local field_in_index = false
                for _, index in pairs(space.index) do
                    for _, index_part in pairs(index.parts) do
                        if index_part.fieldno == fieldno then
                            field_in_index = true
                            break
                        end
                    end
                end

                if field_in_index or field_format.type ~= "string" and field_format.type ~= "array" then
                    goto continue
                end

                local uncompressed_space =
                    create_tmp_space(space_name, '_tmp_uncompressed',
                        unique_index, space:format(), field_format)
                field_format.compression = 'zstd' -- zstd lz4
                local compressed_space =
                    create_tmp_space(space_name, '_tmp_compressed',
                        unique_index, space:format(), field_format)
                local index_space =
                    create_tmp_space(space_name, '_tmp_index',
                        unique_index, space:format(), nil)

                local random_seed = 0
                local added = 0
                local temp_space_len = space:len()
                local temp_space_len_limit = 2000
                if temp_space_len > temp_space_len_limit then
                    temp_space_len = temp_space_len_limit
                end

                local uncompress_time = 0
                local compress_time = 0

                -- fill temporary spaces with limited count of items
                while added < temp_space_len do
                    random_seed = random_seed + 1
                    local full_tuple = unique_index:random(random_seed)
                    local tmp_tuple = {}
                    for _, index_part in pairs(unique_index.parts) do
                        local key_field = full_tuple[index_part.fieldno]
                        table.insert(tmp_tuple, key_field)
                    end

                    local exist_in_compressed_space = index_space:get(tmp_tuple)
                    if exist_in_compressed_space == nil then
                        -- tmp spaces does not yield after insert,
                        -- so need to call yeild explicit.

                        index_space:insert(tmp_tuple)
                        fiber.yield()

                        table.insert(tmp_tuple, full_tuple[fieldno])

                        local time = clock.proc64()
                        uncompressed_space:insert(tmp_tuple)
                        uncompress_time = uncompress_time + clock.proc64() - time
                        fiber.yield()

                        time = clock.proc64()
                        compressed_space:insert(tmp_tuple)
                        compress_time = compress_time + clock.proc64() - time
                        fiber.yield()

                        added = added + 1
                    end
                end

                local field_compression_info = {
                    field_name = field_format.name,
                    compression_percentage =
                        (compressed_space:bsize() - index_space:bsize()) * 100 /
                        (uncompressed_space:bsize() - index_space:bsize() + 1),
                    compression_time = 100 - 100 * uncompress_time / compress_time,
                }
                table.insert(space_compression_info, field_compression_info)

                compressed_space:drop()
                uncompressed_space:drop()
                index_space:drop()

                log.info('Field "%s" in space "%s" can be compressed down to %q%%. Slowdown %q%%.',
                    space_name,
                    field_compression_info.field_name,
                    field_compression_info.compression_percentage,
                    field_compression_info.compression_time)

                ::continue::
            end


            table.insert(storage_compression_info, {
                space_name = space_name,
                fields_be_compressed = space_compression_info})
        end
    end

    return {
        storage_compression_info,
    }, nil
end

return {
    get_cluster_compression_info = get_cluster_compression_info,
}
