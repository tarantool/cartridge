local _ = require('cartridge.issues')
local gql_types = require('cartridge.graphql.types')

local gql_type_warning = gql_types.object({
    name = 'Issue',
    fields = {
        level = gql_types.string.nonNull,
        message = gql_types.string.nonNull,
        replicaset_uuid = gql_types.string,
        instance_uuid = gql_types.string,
        topic = gql_types.string.nonNull,
    }
})

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'issues',
        doc = 'List issues in cluster',
        args = {},
        kind = gql_types.list(gql_type_warning.nonNull),
        callback = 'cartridge.issues.list_on_cluster',
    })
end

return {
    init = init,
}
