local module_name = 'cartridge.webui.api-failover'

local gql_types = require('cartridge.graphql.types')
local lua_api_failover = require('cartridge.lua-api.failover')


local gql_type_userapi = gql_types.object({
    name = 'FailoverAPI',
    description = 'Failover parameters managent',
    fields = {
        mode = {
            kind = gql_types.string.nonNull,
            description = 'Supported modes are "disabled",' ..
                ' "eventual" and "stateful".',
        },
        coordinator_uri = {
            kind = gql_types.string,
            description = 'URI of external coordinator.',
        },
    }
})

local function get_failover_params(_, _)
    return lua_api_failover.get_params()
end

local function set_failover_params(_, args)
    local ok, err = lua_api_failover.set_params(args)
    if ok == nil then
        return nil, err
    end

    return get_failover_params()
end

local function get_failover_enabled(_, _)
    return lua_api_failover.get_failover_enabled()
end

local function set_failover_enabled(_, args)
    return lua_api_failover.set_failover_enabled(args.enabled)
end

local function init(graphql)

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Get current failover state.'
            .. ' (Deprecated since v2.0.1-??)',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.get_failover_enabled',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Enable or disable automatic failover. '
            .. 'Returns new state.'
            .. ' (Deprecated since v2.0.1-??)',
        args = {
            enabled = gql_types.boolean.nonNull,
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.set_failover_enabled',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover_params',
        doc = 'Get automatic failover configuration.',
        args = {},
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.get_failover_params',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover_params',
        doc = 'Configure automatic failover.',
        args = {
            mode = gql_types.string,
            coordinator_uri = gql_types.string,
        },
        kind = gql_type_userapi.nonNull,
        callback = module_name .. '.set_failover_params',
    })
end

return {
    init = init,
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,
    get_failover_params = get_failover_params,
    set_failover_params = set_failover_params,
}
