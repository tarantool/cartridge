local module_name = 'cartridge.webui.api-compression'

local gql_types = require('graphql.types')
local lua_api_compression = require('cartridge.lua-api.compression')

local gql_field_compression_info = gql_types.object({
    name = 'FieldCompressionInfo',
    description = 'Information about single field compression rate possibility',
    fields = {
        field_name = {
            kind = gql_types.string.nonNull,
            description = 'field name',
        },
        compression_percentage = {
            kind = gql_types.int.nonNull,
            description = 'compression percentage',
        },
        compression_time = {
            kind = gql_types.int.nonNull,
            description = 'compression time',
        },
    }
})

local gql_space_compression_info = gql_types.object({
    name = 'SpaceCompressionInfo',
    description = 'List of fields compression info',
    fields = {
        space_name = {
            kind = gql_types.string.nonNull,
            description = 'space name',
        },
        fields_be_compressed = {
            kind = gql_types.list(gql_field_compression_info.nonNull).nonNull,
            description = 'list of fields be compressed',
        },
    }
})

local gql_instance_compression_info = gql_types.object({
    name = 'InstanceCompressionInfo',
    description = 'Combined info of all user spaces in the instance',
    fields = {
        instance_id = {
            kind = gql_types.string.nonNull,
            description = 'instance id',
        },
        instance_compression_info = {
            kind = gql_types.list(gql_space_compression_info.nonNull).nonNull,
            description = 'instance compression info',
        },
    }
})

local gql_cluster_compression_info = gql_types.object({
    name = 'ClusterCompressionInfo',
    description = 'Compression info of all cluster instances',
    fields = {
        compression_info = {
            kind = gql_types.list(gql_instance_compression_info.nonNull).nonNull,
            description = 'cluster compression info',
        },
    }
})


local function get_cluster_compression_info(_, _, _)
    local compression, err = lua_api_compression.get_cluster_compression_info()
    if compression == nil then
        return nil, err
    end
    return compression
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'cluster_compression',
        doc = 'compression info about cluster',
        args = {},
        kind = gql_cluster_compression_info.nonNull,
        callback = module_name .. '.get_cluster_compression_info',
    })
end

return {
    init = init,
    get_cluster_compression_info = get_cluster_compression_info,
}
