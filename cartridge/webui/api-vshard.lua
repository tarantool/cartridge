local gql_types = require('cartridge.graphql.types')
local vshard_utils = require('cartridge.vshard-utils')
local _ = require('cartridge.lua-api.vshard')
local module_name = 'cartridge.webui.api-vshard'

local gql_type_vsgroup = gql_types.object({
    name = 'VshardGroup',
    description = 'Group of replicasets sharding the same dataset',
    fields = {
        name = {
            kind = gql_types.string.nonNull,
            description = 'Group name',
        },
        bucket_count = {
            kind = gql_types.int.nonNull,
            description = 'Virtual buckets count in the group',
        },
        bootstrapped = {
            kind = gql_types.boolean.nonNull,
            description = 'Whether the group is ready to operate',
        },
        rebalancer_max_receiving = {
            kind = gql_types.int.nonNull,
            description =
                'The maximum number of buckets that can be received in parallel by a single replica set ' ..
                'in the storage group'
        },
        collect_lua_garbage = {
            kind = gql_types.boolean.nonNull,
            description = 'If set to true, the Lua collectgarbage() function is called periodically'
        },
        sync_timeout = {
            kind = gql_types.float.nonNull,
            description = 'Timeout to wait for synchronization of the old master with replicas before demotion'
        },
        collect_bucket_garbage_interval = {
            kind = gql_types.float.nonNull,
            description = 'The interval between garbage collector actions, in seconds'
        },
        rebalancer_disbalance_threshold = {
            kind = gql_types.float.nonNull,
            description = 'A maximum bucket disbalance threshold, in percent'
        },
    }
})

-- This function is used in frontend only,
-- returned value is useless for any other purpose.
-- It is to be refactored later.
local function get_vshard_bucket_count()
    -- errors.deprecate(
    --     'GraphQL query "vshard_bucket_count" is deprecated. ' ..
    --     'Query "vshard_groups" instead.'
    -- )
    local vshard_groups = vshard_utils.get_known_groups()
    local sum = 0
    for _, g in pairs(vshard_groups) do
        sum = sum + g.bucket_count
    end
    return sum
end

local function get_vshard_known_groups()
    -- errors.deprecate(
    --     'GraphQL query "vshard_known_groups" is deprecated. ' ..
    --     'Query "vshard_groups" instead.'
    -- )
    local vshard_groups = vshard_utils.get_known_groups()
    local ret = {}
    for name, _ in pairs(vshard_groups) do
        table.insert(ret, name)
    end
    table.sort(ret)
    return ret
end

local function get_vshard_groups()
    local vshard_groups = vshard_utils.get_known_groups()
    local ret = {}
    for name, g in pairs(vshard_groups) do
        g.name = name
        table.insert(ret, g)
    end
    table.sort(ret, function(l, r) return l.name < r.name end)
    return ret
end

local function edit_vshard_options(_, args)
    local group_name = args.name
    args.name = nil

    local _, err = vshard_utils.edit_vshard_options(group_name, args)
    if err ~= nil then
        return nil, err
    end

    local group = vshard_utils.get_known_groups()[group_name]
    group.name = group_name
    return group
end

local function init(graphql)
    graphql.add_mutation({
        name = 'bootstrap_vshard',
        args = {},
        kind = gql_types.boolean,
        callback = 'cartridge.lua-api.vshard.bootstrap_vshard',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'can_bootstrap_vshard',
        doc = 'Whether it is reasonble to call bootstrap_vshard mutation',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = 'cartridge.vshard-utils.can_bootstrap',
    })

    -- deprecated
    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_bucket_count',
        doc = 'Virtual buckets count in cluster',
        args = {},
        kind = gql_types.int.nonNull,
        callback = module_name .. '.get_vshard_bucket_count',
    })

    -- deprecated
    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_known_groups',
        doc = 'Get list of known vshard storage groups.',
        args = {},
        kind = gql_types.list(gql_types.string.nonNull).nonNull,
        callback = module_name .. '.get_vshard_known_groups',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_groups',
        args = {},
        kind = gql_types.list(gql_type_vsgroup.nonNull).nonNull,
        callback = module_name .. '.get_vshard_groups',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'edit_vshard_options',
        args = {
            name = gql_types.string.nonNull,
            rebalancer_max_receiving = gql_types.int,
            collect_lua_garbage = gql_types.boolean,
            sync_timeout = gql_types.float,
            collect_bucket_garbage_interval = gql_types.float,
            rebalancer_disbalance_threshold = gql_types.float,
        },
        kind = gql_type_vsgroup.nonNull,
        callback = module_name .. '.edit_vshard_options',
    })
end

return {
    init = init,

    get_vshard_bucket_count = get_vshard_bucket_count,
    get_vshard_known_groups = get_vshard_known_groups,
    get_vshard_groups = get_vshard_groups,
    edit_vshard_options = edit_vshard_options
}
