local errors = require('errors')
local netbox = require('net.box')

local pool = require('cartridge.pool')
local failover = require('cartridge.failover')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
local ddl_manager = require('cartridge.ddl-manager')
local gql_types = require('graphql.types')
local module_name = 'cartridge.webui.api-ddl'

local GetSchemaError = errors.new_class('GetSchemaError')
local CheckSchemaError = errors.new_class('CheckSchemaError')
local _section_name = ddl_manager._section_name

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
    local schema_yml = confapplier.get_readonly(_section_name)
    if schema_yml == nil or schema_yml == '' then
        schema_yml = ddl_manager._example_schema
    end

    return {
        as_yaml = schema_yml,
    }
end

local function graphql_set_schema(_, args)
    if confapplier.get_readonly() == nil then
        return nil, GetSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end
    local patch = {[_section_name] = args.as_yaml}
    local ok, err = twophase.patch_clusterwide(patch)
    if not ok then
        return nil, err
    end

    return graphql_get_schema()
end

local function graphql_check_schema(_, args)
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return nil, CheckSchemaError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    local conf_new = {[_section_name] = args.as_yaml}
    local conf_old = {[_section_name] = confapplier.get_readonly(_section_name)}

    local active_leaders = failover.get_active_leaders()
    local uri, conn
    if active_leaders[box.info.cluster.uuid] == box.info.uuid then
        conn = netbox.self
    else
        for _, leader_uuid in pairs(active_leaders) do
            uri = topology_cfg.servers[leader_uuid].uri
            conn = pool.connect(uri, {wait_connected = false})

            if conn:wait_connected() then
                break
            end
        end
    end

    if not conn:is_connected() then
        return nil, CheckSchemaError:new('%q: %s',
            uri, conn.error or "Connection not established (yet)"
        )
    end

    local ret, err = errors.netbox_eval(conn,
        [[
            local ddl_manager = require('cartridge.ddl-manager')
            local ok, err = ddl_manager.validate_config(...)
            if ok then
                return { error = box.NULL }
            else
                return { error = err.err }
            end
        ]],
        {conf_new, conf_old}
    )

    if ret == nil then
        return nil, err
    end

    return ret
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
        doc = 'Checks that schema can be applied on cluster',
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
