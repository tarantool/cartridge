local errors = require('errors')
local gql_types = require('graphql.types')

local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')
local module_name = 'cartridge.webui.api-ddl'

local GetSchemaError = errors.new_class('GetSchemaError')
local CheckSchemaError = errors.new_class('CheckSchemaError')

local gql_type_schema = gql_types.object({
    name = 'DDLSchema',
    description = 'The schema',
    fields = {
        as_yaml = gql_types.string.nonNull,
    }
})

local gql_type_check_result = gql_types.object({
    name = 'DDLCheckResult',
    description = 'Result of schema validation',
    fields = {
        error = {
            kind = gql_types.string,
            description = 'Error details if validation fails,' ..
                ' null otherwise',
        },
    }
})

local function graphql_get_schema()
    if confapplier.get_readonly() == nil then
        return nil, GetSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    local ddl_manager = assert(service_registry.get('ddl-manager'))
    return {as_yaml = ddl_manager.get_clusterwide_schema_yaml()}
end

local function graphql_set_schema(_, args)
    if confapplier.get_readonly() == nil then
        return nil, CheckSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    local ddl_manager = assert(service_registry.get('ddl-manager'))
    local ok, err = ddl_manager.set_clusterwide_schema_yaml(args.as_yaml)
    if ok == nil then
        return nil, err
    end

    return graphql_get_schema()
end

local function graphql_check_schema(_, args)
    if confapplier.get_readonly() == nil then
        return nil, CheckSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    local ddl_manager = assert(service_registry.get('ddl-manager'))
    local ok, err = ddl_manager.check_schema_yaml(args.as_yaml)
    if ok then
        return { error = box.NULL }
    elseif err.class_name == ddl_manager.CheckSchemaError.name then
        return { error = err.err }
    else
        return nil, err
    end
end

local function init(graphql)
    graphql.add_callback({
        prefix = 'cluster',
        name = 'schema',
        doc = 'Clusterwide DDL schema',
        args = {},
        kind = gql_type_schema.nonNull,
        callback = module_name .. '.graphql_get_schema',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'schema',
        doc = 'Applies DDL schema on cluster',
        args = {
            as_yaml = gql_types.string.nonNull,
        },
        kind = gql_type_schema.nonNull,
        callback = module_name .. '.graphql_set_schema',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'check_schema',
        doc = 'Checks that the schema can be applied on the cluster',
        args = {
            as_yaml = gql_types.string.nonNull,
        },
        kind = gql_type_check_result.nonNull,
        callback = module_name .. '.graphql_check_schema',
    })

    return true
end

return {
    init = init,
    graphql_get_schema = graphql_get_schema,
    graphql_set_schema = graphql_set_schema,
    graphql_check_schema = graphql_check_schema,
}
