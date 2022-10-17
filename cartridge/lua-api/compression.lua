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
            if space_name == "myspace" then goto continue end
            local space = box.space[space_name]

            local space_len = space:len()
            log.info("space:len() %d", space_len)

            local space_format = space:format()
            log.info(space_format)
            -- newspace - пустой формат

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
            ]]--

            local index = space.index[0]
            log.info(space.index)

            if (index ~= nil) and (index["unique"]) and (next(space_format) ~= nil) then

                for format_k, format in pairs(space_format) do
                    if format.type == "string" then
                        log.error("STRING FIELD")

                        local compressed_len = space_len
                        if space_len > 10000 then
                            compressed_len = 10000
                        end

                        if box.space[space_name..'_compressed'] ~=nil then
                            log.error("DROP")
                            box.space[space_name..'_compressed']:drop()
                        end

                        local compressed_space = box.schema.create_space(space_name..'_compressed', {
                            temporary = true,
                            format = space_format,
                            if_not_exists = true,
                        })

                        compressed_space:create_index('tree', {
                            unique = index["unique"],
                            name = index["name"],
                            type = index["type"],
                            --parts = index["parts"], -- TODO
                            -- Illegal parameters, options.parts[1]: field (name or number) is expected
                        })

                        compressed_space:format({
                            {name = 'index', type = 'unsigned'},
                            {name = 'data', type = 'string', compression = 'lz4'},
                            -- компрессия только с ентерпрайсом
                            -- cd ~/sdk
                            -- . tarantool-enterprise/env.sh
                        })

                        math.randomseed(os.clock())
                        for i = 1, space_len do
                            local rndm = math.random(space_len)-1
                            local r = index:random(rndm)
                            log.info("random %d %s, %s", i, r)
                        end

                        for sk, sv in space:pairs() do
                            log.info(sv)
                        end
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
