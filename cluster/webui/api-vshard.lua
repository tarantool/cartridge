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
end

return {
    init = init,
}
