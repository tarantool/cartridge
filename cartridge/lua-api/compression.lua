local modul_name = 'cartridge.lua-api.compression'
local log = require('log')
local lua_api_get_topology = require('cartridge.lua-api.get-topology')
local pool = require('cartridge.pool')
local errors = require('errors')

local function get_cluster_compression_info()
    local replicasets, err = lua_api_get_topology.get_replicasets()
    if replicasets == nil then
        log.error(err)
        return nil, err
    end

    for _, rpl in pairs(replicasets or {}) do
        for _, role in pairs(rpl.roles or {}) do
            if role == 'vshard-storage' then
                local master = rpl["active_master"]
                log.info(master)

                log.info('>>>>>>>>>>>>>>>>>>')
                local instance_compression, err = errors.netbox_call(
                    pool.connect(master['uri'], {wait_connected = true}),
                    '_G.getStorageCompressionInfo', {master}, {timeout = 1}
                )
                if instance_compression == nil then
                    error(err)
                end

                log.info('<><><><><><><><><>')
                log.info(instance_compression)
                log.info('<<<<<<<<<<<<<<<<<<')
            end
        end
    end

    return {
        cluster_id = '000000qwe',
    }
end

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
 end

function string:endswith(ending)
    return ending == "" or self:sub(-#ending) == ending
end


function _G.getStorageCompressionInfo(server_info)
    log.info("getStorageCompressionInfo")
    log.info(server_info)
    local space_info_name_pos = 3

    local retval = {}

    for _, space_info in box.space._space:pairs() do
        if not string.starts(space_info[space_info_name_pos], "_") then
            log.warn("-------------------------------------------")
            log.warn(space_info)

            local space_name = space_info[space_info_name_pos]
            if space_name:endswith('_compressed') then -- debug
                log.error("DROP FROM PREV RUN")
                box.space[space_name]:drop()
                goto continue
            end

            local space = box.space[space_name]

            local space_len = space:len()
            local compressed_len = space_len
            if space_len > 10000 then
                compressed_len = 10000
            end

            local space_format = space:format()
            -- newspace - пустой формат
            -- myspace : [{"name":"i","type":"number"},{"name":"b","type":"string"}]
            local index = space.index[0]
            -- myspace: {"unique":true,"parts":[{"type":"unsigned","is_nullable":false,"fieldno":1}],"hint":true,"id":0,"type":"TREE","name":"primary","space_id":513}

            if (index ~= nil) and (index["unique"]) and (next(space_format) ~= nil) then
                -- TODO нужно сделать две идентичные таблицы но одна сжатая
                local index_format = {} -- формат сложного индекса
                local index_parts = {} -- для индекса нового спейса в create_index
                for part_k, part in pairs(index.parts) do
                    table.insert(index_format, space_format[part.fieldno])
                    table.insert(index_parts, {
                        field = part_k,
                        type = part.type,
                    })
                end

                for format_k, format in pairs(space_format) do
                    local field_in_index = false
                    for _, part in pairs(index.parts) do
                        if part.fieldno == format_k then
                            field_in_index = true
                        end
                    end

                    -- скипаем поля из индекса и не строковые поля
                    if not field_in_index and format.type == "string" then
                        format.compression = 'zstd' -- zstd lz4

                        if box.space[space_name..'_compressed'] ~=nil then
                            box.space[space_name..'_compressed']:drop()
                        end

                        local compressed_space_format = {}
                        for _, f in pairs(index_format) do
                            table.insert(compressed_space_format, f)
                        end
                        table.insert(compressed_space_format, format)

                        local compressed_space = box.schema.create_space(space_name..'_compressed', {
                            temporary = true,
                            format = compressed_space_format,
                            if_not_exists = true,
                        })

                        -- создаем спейс из индексных полей и одного строкового поля
                        compressed_space:create_index(index["name"], {
                            unique = index["unique"],
                            type = index["type"],
                            parts = index_parts,
                        })

                        local random_seed = 0
                        local added = 1
                        while added <= compressed_len do
                            random_seed = random_seed + 1
                            local tuple = index:random(random_seed)
                            --local multipart_key = {}
                            --for part_k, part in pairs(index.parts) do
                            --    local key_field = tuple[part.fieldno]
                            --    table.insert(multipart_key, key_field)
                                --multikey:update({{'=', part_k, key_field}})
                                --multikey:transform(part_k, 1, key_field)
                            --end
                            --log.error("multipart_key:")
                            --log.error(multipart_key)
                            --local a = table:unpack(multipart_key)
                            --log.error(a)
                            --local key_tuple = box.tuple.new{ table.unpack(multipart_key) }
                            --log.error(key_tuple)

                            local exist = compressed_space:get{tuple[1]} -- ключ может быть составным и не на 1 месте!
                            if exist == nil then
                                compressed_space:insert{tuple[1], tuple[format_k]}
                                added = added + 1
                            end
                        end

                        table.insert(retval, {space_name, space:bsize(), compressed_space:bsize()})

                        if box.space[space_name..'_compressed'] ~=nil then
                            box.space[space_name..'_compressed']:drop()
                        end

                        --for sk, sv in space:pairs() do
                        --    log.info(sv)
                        --end
                    end
                end
            end
        end
        ::continue::
    end

    return {
        retval,
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
