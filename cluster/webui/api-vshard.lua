#!/usr/bin/env tarantool

local rpc = require('cluster.rpc')
local admin = require('cluster.admin')
local gql_types = require('cluster.graphql.types')
local module_name = 'cluster.webui.api-vshard'

local function init(graphql)
    graphql.add_mutation({
        name = 'bootstrap_vshard',
        args = {},
        kind = gql_types.boolean,
        callback = module_name .. '.bootstrap_vshard',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'can_bootstrap_vshard',
        doc = 'Whether it is reasonble to call bootstrap_vshard mutation',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.can_bootstrap_vshard',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_bucket_count',
        doc = 'Virtual buckets count in cluster',
        args = {},
        kind = gql_types.int.nonNull,
        callback = module_name .. '.vshard_bucket_count',
    })
end

return {
    init = init,
    bootstrap_vshard = function()
        return rpc.call('vshard-router', 'bootstrap')
    end,
    vshard_bucket_count = admin.vshard_bucket_count,
    can_bootstrap_vshard = admin.can_bootstrap_vshard,
}
