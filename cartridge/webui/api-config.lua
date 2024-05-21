local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local errors = require('errors')
local checks = require('checks')

local utils = require('cartridge.utils')
local gql_types = require('graphql.types')
local module_name = 'cartridge.webui.api-config'

json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local DecodeYamlError = errors.new_class('DecodeYamlError')
local DownloadConfigError = errors.new_class('Config download failed')
local UploadConfigError = errors.new_class('Config upload failed')
local ForceReapplyError = errors.new_class('Config reapply failed')
local ValidateConfigError = errors.new_class('Config validate failed')

local auth = require('cartridge.auth')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
local service_registry = require('cartridge.service-registry')
local ClusterwideConfig = require('cartridge.clusterwide-config')

local system_sections = {
    ['auth'] = true,
    ['auth.yml'] = true,
    ['topology'] = true,
    ['topology.yml'] = true,
    ['users_acl'] = true,
    ['users_acl.yml'] = true,
    ['vshard'] = true,
    ['vshard.yml'] = true,
    ['vshard_groups'] = true,
    ['vshard_groups.yml'] = true,
}

local gql_type_section = gql_types.object({
    name = 'ConfigSection',
    description = 'A section of clusterwide configuration',
    fields = {
        filename = gql_types.string.nonNull,
        content = gql_types.string.nonNull
    }
})

local gql_type_section_input = gql_types.inputObject({
    name = 'ConfigSectionInput',
    description = 'A section of clusterwide configuration',
    fields = {
        filename = gql_types.string.nonNull,
        content = gql_types.string
    }
})

local gql_type_validate_result = gql_types.object({
    name = 'ValidateConfigResult',
    description = 'Result of config validation',
    fields = {
        error = {
            kind = gql_types.string,
            description = 'Error details if validation fails,' ..
                ' null otherwise',
        },
    }
})

local function http_finalize_error(http_code, err)
    log.error('%s', err)

    return auth.render_response({
        status = http_code,
        headers = {
            ['content-type'] = "application/json; charset=utf-8"
        },
        body = json.encode(err),
    })
end

local function download_config_handler(req)
    if not auth.authorize_request(req) then
        local err = DownloadConfigError:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    local clusterwide_config = confapplier.get_active_config()
    if clusterwide_config == nil then
        local err = DownloadConfigError:new(
            "Current instance isn't bootstrapped yet"
        )
        return http_finalize_error(409, err)
    end

    -- cut system sections
    local blacklist = table.copy(system_sections)
    for section, _ in pairs(clusterwide_config:get_readonly()) do
        -- don't download yaml representation of a section
        if clusterwide_config:get_plaintext(section .. '.yml') then
            blacklist[section .. '.yml'] = true
        end
    end

    local ret = {}
    for section, data in pairs(clusterwide_config:get_readonly()) do
        if not blacklist[section] then
            ret[section] = data
        end
    end

    return auth.render_response({
        status = 200,
        headers = {
            ['content-type'] = "application/yaml",
            ['content-disposition'] = 'attachment; filename="config.yml"',
        },
        body = yaml.encode(ret)
    })
end

local function upload_config(clusterwide_config)
    checks('ClusterwideConfig')
    local patch = {}

    for k, _ in pairs(confapplier.get_active_config():get_plaintext()) do
        if not system_sections[k] then
            patch[k] = box.NULL
        end
    end

    for k, v in pairs(clusterwide_config:get_plaintext()) do
        if system_sections[k] then
            local err = UploadConfigError:new(
                "uploading system section %q is forbidden", k
            )
            return nil, err
        else
            patch[k] = v
        end
    end

    return twophase.patch_clusterwide(patch)
end

local function upload_config_handler(req)
    if not auth.authorize_request(req) then
        local err = UploadConfigError:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    if confapplier.get_readonly() == nil then
        local err = UploadConfigError:new(
            "Current instance isn't bootstrapped yet"
        )
        return http_finalize_error(409, err)
    end

    local req_body = utils.http_read_body(req)
    local conf_new, err
    if req_body == nil then
        conf_new, err = nil, UploadConfigError:new('Request body must not be empty')
    else
        conf_new, err = DecodeYamlError:pcall(yaml.decode, req_body)
    end

    if err ~= nil then
        return http_finalize_error(400, err)
    elseif type(conf_new) ~= 'table' then
        err = UploadConfigError:new('Config must be a table')
        return http_finalize_error(400, err)
    end

    log.warn('Config uploaded')

    local clusterwide_config = ClusterwideConfig.new()

    for k, v in pairs(conf_new) do
        if system_sections[k] then
            local err = UploadConfigError:new(
                "uploading system section %q is forbidden", k
            )
            return http_finalize_error(400, err)
        elseif type(conf_new[k .. '.yml']) ~= 'nil' then
            local err = UploadConfigError:new(
                "ambiguous sections %q and %q", k, k .. '.yml'
            )
            return http_finalize_error(400, err)
        elseif v == nil or type(v) == 'string' then
            clusterwide_config:set_plaintext(k, v)
        else
            clusterwide_config:set_plaintext(k .. '.yml', yaml.encode(v))
        end
    end

    local ok, err = upload_config(clusterwide_config)
    if ok == nil then
        return http_finalize_error(400, err)
    end

    return auth.render_response({status = 200})
end

local function get_sections(_, args)
    checks('?', {sections = '?table'})
    local clusterwide_config = confapplier.get_active_config()
    if clusterwide_config == nil then
        local err = DownloadConfigError:new(
            "Current instance isn't bootstrapped yet"
        )
        return nil, err
    end

    local ret = {}
    for section, content in pairs(clusterwide_config:get_plaintext()) do
        if (args.sections == nil or utils.table_find(args.sections, section))
        and not system_sections[section] then
            table.insert(ret, {
                filename = section,
                content = content,
            })
        end
    end

    return ret
end

local function set_sections(_, args)
    checks('?', {sections = '?table'})
    if confapplier.get_readonly() == nil then
        local err = UploadConfigError:new(
            "Current instance isn't bootstrapped yet"
        )
        return nil, err
    end

    if args.sections == nil then
        args.sections = {}
    end

    local patch = {}
    local query_sections = {}

    for _, input in ipairs(args.sections) do
        if system_sections[input.filename] then
            return nil, UploadConfigError:new(
                "uploading system section %q is forbidden",
                input.filename
            )
        end

        patch[input.filename] = input.content or box.NULL
        table.insert(query_sections, input.filename)
    end

    local ok, err = twophase.patch_clusterwide(patch)
    if not ok then
        return nil, err
    end

    return get_sections(nil, {sections = query_sections})
end

local function validate_config(_, args)
    if confapplier.get_readonly() == nil then
        return nil, ValidateConfigError:new(
            "Current instance isn't bootstrapped yet"
        )
    end

    if args.sections == nil then
        args.sections = {}
    end

    local patch = {}
    for _, input in ipairs(args.sections) do
        patch[input.filename] = input.content or box.NULL
    end

    -- Check schema if present. However, it is done in
    -- confapplier.validate_config as well but only for leaders. The
    -- following is used to perform the validation on non-leader instances.
    if patch['schema.yml'] and not require('cartridge.failover').is_leader() then
        local ddl_manager
        local ok, _ = pcall(require, 'ddl-ee')
        if not ok then
            ddl_manager = assert(service_registry.get('ddl-manager'))
        else
            ddl_manager = assert(service_registry.get('ddl-manager-ee'))
        end
        local ok, err = ddl_manager.check_schema_yaml(args.as_yaml)
        if not ok then
            if err.class_name == ddl_manager.CheckSchemaError.name then
                return { error = err.err }
            else
                return nil, err
            end
        end
    end

    local active_config = confapplier.get_active_config()
    local draft_config = active_config:copy_and_patch(patch)
    draft_config:lock()

    -- Check topology
    local active_topology = draft_config:get_readonly('topology')
    local draft_topology = draft_config:get_readonly('topology')
    local _, err = require('cartridge.topology').validate(draft_topology, active_topology)
    if err then
        return { error = err.err }

    end

    -- Check vshard
    local _, err = require('cartridge.vshard-utils').validate_config(
        active_config:get_readonly(),
        draft_config:get_readonly()
    )
    if err then
        return { error = err.err }
    end

    -- Let confapplier to validate it too, why not
    local _, err = confapplier.validate_config(draft_config)
    if err then
        return { error = err.err }
    end

    return { error = box.NULL }
end

local function force_reapply(_, args)
    checks('?', {uuids = '?table'})
    if confapplier.get_readonly() == nil then
        local err = ForceReapplyError:new(
            "Current instance isn't bootstrapped yet"
        )
        return nil, err
    end

    local ok, err = twophase.force_reapply(args.uuids)
    if not ok then
        return nil, err
    end

    return true
end

local function init(graphql, httpd, opts)
    checks('table', 'table', {
        prefix = 'string',
    })
    graphql.add_callback({
        prefix = 'cluster',
        name = 'config',
        doc = 'Get cluster config sections',
        args = {
            sections = gql_types.list(gql_types.string.nonNull)
        },
        kind = gql_types.list(gql_type_section).nonNull,
        callback = module_name .. '.get_sections',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'config',
        doc = 'Applies updated config on the cluster',
        args = {
            sections = gql_types.list(gql_type_section_input)
        },
        kind = gql_types.list(gql_type_section).nonNull,
        callback = module_name .. '.set_sections',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'validate_config',
        doc = 'Validate config',
        args = {
            sections = gql_types.list(gql_type_section_input)
        },
        kind = gql_type_validate_result.nonNull,
        callback = module_name .. '.validate_config',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'config_force_reapply',
        doc = 'Reapplies config on the specified nodes',
        args = {
            uuids = gql_types.list(gql_types.string)
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.force_reapply',
    })

    httpd:route({
        path = opts.prefix .. '/admin/config',
        method = 'PUT'
    }, upload_config_handler)
    httpd:route({
        path = opts.prefix .. '/admin/config',
        method = 'GET'
    }, download_config_handler)

    return true
end

return {
    init = init,
    get_sections = get_sections,
    set_sections = set_sections,
    validate_config = validate_config,
    force_reapply = force_reapply,

    upload_config = upload_config,
}
