local lua_api_get_topology = require('cartridge.lua-api.get-topology')
local log = require('log')

local pool = require('cartridge.pool')
local errors = require('errors')

--- This function gets compression info on cluster aggregated by instances.
-- Function surfs by replicates to find master storages and calls on them getStorageCompressionInfo() func.
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

                local conn, err = pool.connect(master.uri, {wait_connected = true})
                if not conn or err ~= nil then
                    if err ~=nil then
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
                    '_G.getStorageCompressionInfo', {master}, {timeout = 1}
                )

                if storage_compression_info == nil or err ~= nil then
                    if err ~=nil then
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
-- @function create_test_space
-- @local
-- @tparam string space_name
-- @tparam string space_type
-- @tparam table orig_index
-- @tparam string orig_format
-- @tparam string field_format
-- @treturn table
local function create_test_space(space_name, space_type, orig_index, orig_format, field_format)
    if space_type == '' then
        error('need suffix for space name')
    end
    local tmp_space = space_name..space_type
    if box.space[tmp_space] ~= nil then
        box.space[tmp_space]:drop()
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

    local space = box.schema.create_space(tmp_space, {
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

--- This finds all user spaces with correct schema and index and calculates compression for their fields.
-- @function getStorageCompressionInfo
-- @treturn[1] table {{space_name, fields_be_compressed},...}
-- @treturn[2] nil
-- @treturn[2] table Error description
function _G.getStorageCompressionInfo(_)
    local storage_compression_info = {}

    for _, space_info in box.space._space:pairs() do
        local space_info_name_pos = 3
        local space_name = space_info[space_info_name_pos]

        local space_compression_info = {}
        if not space_name:startswith("_") then
            local space = box.space[space_name]
            local space_format = space:format()
            local index = space.index[0]

            if (index ~= nil) and (index.unique == true) and (next(space_format) ~= nil) then
                for field_format_key, field_format in pairs(space_format) do

                    local field_in_index = false
                    for _, index_part in pairs(index.parts) do
                        if index_part.fieldno == field_format_key then
                            field_in_index = true
                        end
                    end

                    if (not field_in_index) and (field_format.type == "string" or field_format.type == "array") then
                        local uncompressed_space =
                            create_test_space(space_name, '_test_uncompressed',
                                space.index[0], space:format(), field_format)
                        field_format.compression = 'zstd' -- zstd lz4
                        local compressed_space =
                            create_test_space(space_name, '_test_compressed',
                                space.index[0], space:format(), field_format)
                        local index_space =
                            create_test_space(space_name, '_test_index',
                                space.index[0], space:format(), nil)

                        local random_seed = 0
                        local added = 1
                        local temp_space_len = space:len()
                        if temp_space_len > 10000 then
                            temp_space_len = 10000
                        end

                        -- fill temporary spaces with limited count of items
                        while added <= temp_space_len do
                            random_seed = random_seed + 1
                            local tuple = index:random(random_seed)

                            local multipart_key = {}
                            for _, index_part in pairs(index.parts) do
                                local key_field = tuple[index_part.fieldno]
                                table.insert(multipart_key, key_field)
                            end

                            local exist_in_compressed_space = compressed_space:get(multipart_key)
                            if exist_in_compressed_space == nil then
                                index_space:insert(multipart_key)
                                table.insert(multipart_key, tuple[field_format_key])
                                uncompressed_space:insert(multipart_key)
                                compressed_space:insert(multipart_key)
                                added = added + 1
                            end
                        end

                        local field_compression_info = {
                            field_name = field_format.name,
                            compression_percentage =
                                (compressed_space:bsize() - index_space:bsize()) * 100 /
                                (uncompressed_space:bsize() - index_space:bsize() + 1),
                        }
                        table.insert(space_compression_info, field_compression_info)

                        compressed_space:drop()
                        uncompressed_space:drop()
                        index_space:drop()
                    end
                end
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
