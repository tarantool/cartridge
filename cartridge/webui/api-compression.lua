local module_name = 'cartridge.webui.api-compression'

local gql_types = require('graphql.types')
local lua_api_compression = require('cartridge.lua-api.compression')
local log = require('log')

--type FieldCompressionInfo {
--  field_name: String!
--  compression_percentage: Int!
--}

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
    }
})

--type SpaceCompressionInfo {
--  space_name: String!
--  fields_be_compressed: [FieldCompressionInfo!]!
--}

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

--type InstanceCompressionInfo {
--  instance_id: String!
--  compression_info: [SpaceCompressionInfo!]!
--}

local gql_instance_compression_info = gql_types.object({
    name = 'InstanceCompressionInfo',
    description = 'Combined info of all user spaces in the instance',
    fields = {
        instance_id = {
            kind = gql_types.string.nonNull,
            description = 'instance id',
        },
        compression_info = {
            kind = gql_types.list(gql_space_compression_info.nonNull).nonNull,
            description = 'instance compression info',
        },
    }
})

--type ClusterCompressionInfo {
--  cluster_id: String!
--  compression_info: [InstanceCompressionInfo!]!
--}

local gql_cluster_compression_info = gql_types.object({
    name = 'ClusterCompressionInfo',
    description = 'Compression info of all cluster instances',
    fields = {
        cluster_id = {
            kind = gql_types.string.nonNull,
            description = 'cluster id',
        },
        compression_info = {
            kind = gql_types.list(gql_instance_compression_info.nonNull).nonNull,
            description = 'cluster compression info',
        },
    }
})

local function get_compression_info(_, _, info)
    --[[
    local cache = info.context.request_cache
    if cache.compression ~= nil then
        return cache.compression
    end
    cache.compression, cache.compression_err = lua_api_compression.get_cluster_compression_info()
    return cache.compression
    ]]--
    local compression = lua_api_compression.get_cluster_compression_info()
    return compression
end

--[[
query {
    cluster {
        cluster_compression {
            cluster_id
            compression_info
        }
    }
}
]]--

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'cluster_compression',
        doc = 'compression info about cluster',
        args = {
        --    uuid = gql_types.string
        },
        kind = gql_cluster_compression_info.nonNull,
        callback = module_name .. '.get_compression_info',
    })
end

return {
    init = init,
    get_compression_info = get_compression_info,
}
