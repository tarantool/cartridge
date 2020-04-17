local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local errors = require('errors')
local checks = require('checks')

local utils = require('cartridge.utils')
local gql_types = require('cartridge.graphql.types')
local module_name = 'cartridge.webui.api-config'

json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
})

local DecodeYamlError = errors.new_class('DecodeYamlError')
local DownloadConfigError = errors.new_class('Config download failed')
local UploadConfigError = errors.new_class('Config upload failed')

local auth = require('cartridge.auth')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
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
        local err = DownloadConfigError:new("Cluster isn't bootstrapped yet")
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
        local err = UploadConfigError:new("Cluster isn't bootstrapped yet")
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
        local err = DownloadConfigError:new("Cluster isn't bootstrapped yet")
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
        local err = UploadConfigError:new("Cluster isn't bootstrapped yet")
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


local function init(graphql, httpd)
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
        doc = 'Applies updated config on cluster',
        args = {
            sections = gql_types.list(gql_type_section_input)
        },
        kind = gql_types.list(gql_type_section).nonNull,
        callback = module_name .. '.set_sections',
    })

    httpd:route({
        path = '/admin/config',
        method = 'PUT'
    }, upload_config_handler)
    httpd:route({
        path = '/admin/config',
        method = 'GET'
    }, download_config_handler)

    return true
end

return {
    init = init,
    get_sections = get_sections,
    set_sections = set_sections,

    upload_config = upload_config,
}
