local module_name = 'cartridge.webui.api-failover'

local gql_types = require('cartridge.graphql.types')
local lua_api_failover = require('cartridge.lua-api.failover')

local function get_failover_enabled(_, _)
    return lua_api_failover.get_params().enabled
end

local function set_failover_enabled(_, args)
    local ok, err = lua_api_failover.set_params(args)
    if ok == nil then
        return nil, err
    end

    return get_failover_enabled()
end

local function init(graphql)

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Get current failover state.',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.get_failover_enabled',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Enable or disable automatic failover. '
            .. 'Returns new state.',
        args = {
            enabled = gql_types.boolean.nonNull,
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.set_failover_enabled',
    })

end

return {
    init = init,
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,
}
