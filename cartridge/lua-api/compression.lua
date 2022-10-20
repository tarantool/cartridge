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
                    '_G.storageGetInfo', {master}, {timeout = 1}
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


function _G.storageGetInfo(params)
    log.info("storageGetInfo")
    log.info(params)
    
    local space_id = 1
    local space_info_name_pos = 3

    local ta = {}
    local i, line
    for space_k, space_info in box.space._space:pairs() do
        i = 1
        line = ''
        while i <= #space_info do
            if type(space_info[i]) ~= 'table' then
                line = line .. space_info[i] .. ' '
            end
            i = i + 1
        end
        table.insert(ta, line)

        if not string.starts(space_info[space_info_name_pos], "_") then
            log.warn("-------------------------------------------")
            log.warn(space_info)

            local space_name = space_info[space_info_name_pos]
            log.info(space_name)

            -- [myspace, newspace]
            --if space_name == "myspace" then
                --goto continue
            --end
            if space_name:endswith('_compressed') then
                log.error("DROP FROM PREV RUN")
                box.space[space_name]:drop()
                goto continue
            end

            local space = box.space[space_name]

            local space_len = space:len()
            log.info("space_len %d", space_len) -- myspace : 4
            
            local space_bsize = space:bsize()
            log.info("space_bsize:")
            log.error(space_bsize)

            local space_format = space:format()
            log.info("space_format:")
            log.info(space_format)
            -- newspace - пустой формат
            -- myspace : [{"name":"i","type":"number"},{"name":"b","type":"string"}]

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

            local index = space.index[0]
            log.info("index:")
            log.info(index)
            -- {"unique":true,"parts":[{"type":"unsigned","is_nullable":false,"fieldno":1}],"hint":true,"id":0,"type":"TREE","name":"primary","space_id":513}

            if (index ~= nil) and (index["unique"]) and (next(space_format) ~= nil) then
                log.info("iiiiiii")

                local index_format = {} -- формат сложного индекса
                local index_parts = {} -- для индекса нового спейса в create_index
                for part_k, part in pairs(index.parts) do
                    table.insert(index_format, space_format[part.fieldno])

                    table.insert(index_parts, {
                        field = part_k,
                        type = part.type,
                    })
                end
                log.info("index_format:")
                log.info(index_format)

                log.info("index_parts:")
                log.info(index_parts)

                for format_k, format in pairs(space_format) do
                    log.info("ffffffff")
                    log.info(format_k)
                    local field_in_index = false
                    for _, part in pairs(index.parts) do
                        if part.fieldno == format_k then
                            field_in_index = true
                            log.warn("skip %d", format_k)
                        end
                    end

                    if not field_in_index and format.type == "string" then
                        log.info("sssssssssss")
                        format.compression = 'zstd' -- zstd lz4

                        local compressed_len = space_len
                        if space_len > 10000 then
                            compressed_len = 10000
                        end

                        if box.space[space_name..'_compressed'] ~=nil then
                            log.error("pre DROP")
                            box.space[space_name..'_compressed']:drop()
                        end

                        local compressed_format = {}
                        for _, f in pairs(index_format) do
                            table.insert(compressed_format, f)
                        end
                        table.insert(compressed_format, format)
                        log.warn("compressed_format:")
                        log.warn(compressed_format)

                        local compressed_space = box.schema.create_space(space_name..'_compressed', {
                            temporary = true,
                            format = compressed_format,
                            if_not_exists = true,
                        })
                        log.info("comressed space created")

                        compressed_space:create_index(index["name"], {
                            unique = index["unique"],
                            type = index["type"],
                            parts = index_parts,
                        })
                        log.info("index created %s", index["name"])
                        log.info(compressed_space.index[0])

                        local seed = 0
                        local compressed_i = 1
                        while compressed_i <= compressed_len do
                            seed = seed + 1
                            local tuple = index:random(seed)
                            local exist = compressed_space:get{tuple[1]}
                            if exist == nil then
                                log.info("insert %d %d", compressed_i, tuple[1])
                                compressed_space:insert{tuple[1], tuple[format_k]}
                                compressed_i = compressed_i+1
                            end
                        end

                        local compressed_space_bsize = compressed_space:bsize()
                        log.info("compressed_space bsize:")
                        log.error(compressed_space_bsize)

                        if box.space[space_name..'_compressed'] ~=nil then
                            log.error("DROP after")
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
        --retval = 321,
        ta,
    }
end

return {
    get_cluster_compression_info = get_cluster_compression_info,
}
