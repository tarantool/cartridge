-- luacheck: globals file
file = {
    "cartridge.lua",
    "cartridge/auth.lua",
    "cartridge/roles.lua",
    "cartridge/issues.lua",
    "cartridge/argparse.lua",
    "cartridge/twophase.lua",
    "cartridge/failover.lua",
    "cartridge/topology.lua",
    "cartridge/clusterwide-config.lua",
    "cartridge/rpc.lua",
    "cartridge/tar.lua",
    "cartridge/pool.lua",
    "cartridge/upload.lua",
    "cartridge/confapplier.lua",
    "cartridge/test-helpers.lua",
    "cartridge/test-helpers/cluster.lua",
    "cartridge/test-helpers/server.lua",
    "cartridge/test-helpers/etcd.lua",
    "cartridge/test-helpers/stateboard.lua",
    "cartridge/remote-control.lua",
    "cartridge/service-registry.lua",
    "cartridge/user-defined-role.lua",

    "cartridge/lua-api/stat.lua",
    "cartridge/lua-api/boxinfo.lua",
    "cartridge/lua-api/get-topology.lua",
    "cartridge/lua-api/edit-topology.lua",
    "cartridge/lua-api/topology.lua",
    "cartridge/lua-api/failover.lua",
    "cartridge/lua-api/vshard.lua",
    "cartridge/lua-api/deprecated.lua",
    "cartridge/lua-api/compression.lua",
}

-- luacheck: globals topics
topics = {
}

-- luacheck: globals format
format = 'markdown'

-- luacheck: globals custom_tags
custom_tags = {
    {'refer', hidden = true},
}

-- luacheck: ignore printall
local function printall(k, v, lvl)
    print(k, v)
    if lvl > 2 then
        return
    end
    if ('%s'):format(v):sub(1, 9) == 'table: 0x'
    or ('%s'):format(v):match('^{.+}$')
    then
        for _k, _v in pairs(v) do
            printall(k..'.'.._k, _v, lvl+1)
        end
    end
end

-- luacheck: globals modules
-- luacheck: globals custom_display_name_handler
custom_display_name_handler = function(item, default_handler)
    if not item.tags.refer then
        return default_handler(item)
    end

    local ref_name = item.tags.refer[1]

    if item.type == 'module' then
        -- print(('Referencing module %s'):format(ref_name))
        local ref_module = modules.by_name[ref_name]
        item.description = ref_module.description
        return default_handler(item)
    end

    if item.type == 'function'
    or item.type == 'table'
    then
        -- print(('Referencing %s %s'):format(item.type, ref_name))
        local module_name, item_name = ref_name:match('^(.+)%.(.-)$')

        local ref_module = modules.by_name[module_name]
        if ref_module == nil then
            print('Module ' .. module_name .. ' not found')
        end

        local ref_item = ref_module.items.by_name[item_name]
        if ref_item == nil then
            print('Function ' .. ref_name .. ' not found')
        end

        item.ret = ref_item.ret
        item.args = ref_item.args
        item.usage = ref_item.usage
        item.params = ref_item.params
        item.summary = ref_item.summary
        item.modifiers = ref_item.modifiers
        item.retgroups = ref_item.retgroups
        item.subparams = ref_item.subparams
        item.description = ref_item.description
        return default_handler(item)
    end

    print(("Can't reference %s %q"):format(item.type, item.name))
    -- printall('item', item, 1)
    error()
end
