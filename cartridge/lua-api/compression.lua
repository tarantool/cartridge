local lua_api_get_topology = require('cartridge.lua-api.get-topology')

local log = require('log')
local pool = require('cartridge.pool')
local errors = require('errors')

local function get_cluster_compression_info()
    local replicasets, err = lua_api_get_topology.get_replicasets()
    if replicasets == nil then
        log.error(err)
        return nil, err
    end

    local compression_info = {}

    for _, rpl in pairs(replicasets or {}) do
        for _, role in pairs(rpl.roles or {}) do
            if role == 'vshard-storage' then
                local master = rpl["master"]

                local storage_compression_info, err = errors.netbox_call(
                    pool.connect(master['uri'], {wait_connected = true}),
                    '_G.getStorageCompressionInfo', {master}, {timeout = 1}
                )
                if storage_compression_info == nil then
                    error(err)
                end

                log.info(storage_compression_info)
                table.insert(compression_info, {
                    instance_id = master.uuid,
                    instance_compression_info = storage_compression_info})
            end
        end
    end

    return {
        compression_info = compression_info,
    }
end

local function create_test_space(space_name, orig_space, field_format)
    if box.space[space_name] ~=nil then
        box.space[space_name]:drop()
    end

    local orig_index = orig_space.index[0]
    local orig_format = orig_space:format()

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

    local space = box.schema.create_space(space_name, {
        temporary = true,
        format = space_format,
        if_not_exists = true,
    })

    space:create_index(orig_index["name"], {
        unique = orig_index["unique"],
        type = orig_index["type"],
        parts = index_parts,
    })

    return space
end

function _G.getStorageCompressionInfo(_)
    local storage_compression_info = {}

    for _, space_info in box.space._space:pairs() do
        local space_info_name_pos = 3
        local space_name = space_info[space_info_name_pos]

        if space_name:endswith('_test_compressed') or
        space_name:endswith('_test_uncompressed') or
        space_name:endswith('_test_index') then -- debug
            box.space[space_name]:drop()
            goto continue
        end

        local space_compression_info = {}
        if not space_name:startswith("_") then
            local space = box.space[space_name]
            local space_format = space:format()
            local index = space.index[0]

            if (index ~= nil) and index["unique"] and (next(space_format) ~= nil) then
                for field_format_key, field_format in pairs(space_format) do

                    local field_in_index = false
                    for _, index_part in pairs(index.parts) do
                        if index_part.fieldno == field_format_key then
                            field_in_index = true
                        end
                    end

                    if (not field_in_index) and field_format.type == "string" then
                        local uncompressed_space =
                            create_test_space(space_name..'_test_uncompressed', space, field_format)
                        field_format.compression = 'zstd' -- zstd lz4
                        local compressed_space = create_test_space(space_name..'_test_compressed', space, field_format)
                        local index_space = create_test_space(space_name..'_test_index', space, nil)

                        local random_seed = 0
                        local added = 1
                        local temp_space_len = space:len()
                        if temp_space_len > 10000 then
                            temp_space_len = 10000
                        end

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
        ::continue::
    end

    return {
        storage_compression_info[1],
    }
end

return {
    get_cluster_compression_info = get_cluster_compression_info,
}


--[[
    компрессия только с ентерпрайсом
    cd ~/sdk
    . tarantool-enterprise/env.sh
    cd ~/cartridge
    cartridge start


    pip install -r rst/requirements.txt
    tarantoolctl rocks install ldoc --server=https://tarantool.github.io/LDoc/
    tarantoolctl rocks make

    cartridge start
    cartridge replicasets setup --bootstrap-vshard


    tarantoolctl connect admin:@127.0.0.1:3302
    box.space.myspace:insert{123, "qwe"}
]]--
