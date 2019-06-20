#!/usr/bin/env tarantool

local gql_types = require('cluster.graphql.types')

local function init(graphql)
    graphql.add_mutation({
        name = 'bootstrap_vshard',
        args = {},
        kind = gql_types.boolean,
        callback = 'cluster.admin' .. '.bootstrap_vshard',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'can_bootstrap_vshard',
        doc = 'Whether it is reasonble to call bootstrap_vshard mutation',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = 'cluster.roles.vshard-router' .. '.can_bootstrap',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_bucket_count',
        doc = 'Virtual buckets count in cluster',
        args = {},
        kind = gql_types.int.nonNull,
        callback = 'cluster.roles.vshard-router' .. '.get_bucket_count',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_known_groups',
        doc = 'Get list of known vshard storage groups.',
        args = {},
        kind = gql_types.list(gql_types.string.nonNull).nonNull,
        callback = 'cluster.roles.vshard-router' .. '.get_known_groups',
    })
end

return {
    init = init,
}
