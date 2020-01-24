#!/usr/bin/env tarantool

require('cartridge.warnings')
local gql_types = require('cartridge.graphql.types')

local gql_type_warning = gql_types.object {
    name = 'Warning',
    description = 'Warning occured on cluser',
    fields = {
        replicaset_uuid = gql_types.string,
        message = gql_types.string,
        instance_uuid = gql_types.string,
    }
}

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'warnings',
        args = {},
        doc = 'Get list of replication warngings',
        kind = gql_types.list(gql_type_warning),
        callback = 'cartridge.warnings.list_on_cluster',
    })
end

return {
    init = init,
}
