local module_name = 'cartridge.webui.api-compression'

local compression = require('cartridge.compression')
local gql_types = require('graphql.types')


local gql_field_compression_info = gql_types.object({
    name = 'FieldCompressionInfo',
    fields = {
        field_name = {
            kind = gql_types.string,
            description = 'field name',
        },
        compression_percentage = {
            kind = gql_types.int,
            description = 'compression percentage',
        },
    }
})

local gql_space_compression_info = gql_types.object({
    name = 'SpaceCompressionInfo',
    fields = {
        space_name = {
            kind = gql_types.string,
            description = 'space name',
        },
        fields_be_compressed = {
            kind = gql_types.list(gql_field_compression_info),
            description = 'list of fields be compressed',
        },
    }
})

local gql_instance_compression_info = gql_types.object({
    name = 'InstanceCompressionInfo',
    fields = {
        instance_id = {
            kind = gql_types.int,
            description = 'instance id',
        },
        compression_info = {
            kind = gql_types.list(gql_space_compression_info),
            description = 'instance compression info',
        },
    }
})

local gql_cluster_compression_info = gql_types.object({
    name = 'ClusterCompressionInfo',
    fields = {
        cluster_id = {
            kind = gql_types.int,
            description = 'cluster id',
        },
        compression_info = {
            kind = gql_types.list(gql_instance_compression_info),
            description = 'cluster compression info',
        },
    }
})

local function get_compression_info(_, _, info)
    local cache = info.context.request_cache
    if cache.compression ~= nil then
        return cache.compression
    end

    cache.compression, cache.compression_err = compression.RESOLVER_get_compression_info()
    return cache.compression
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'compression',
        doc = 'compression info about cluster',
        args = {},
        kind = gql_types.list(gql_cluster_compression_info.nonNull),
        callback = module_name .. '.get_compression_info',
    })
end

return {
    init = init,
    get_compression_info = get_compression_info,
}
