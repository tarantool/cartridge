#!/usr/bin/env tarantool

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local errors = require('errors')

json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
})


local auth = require('cartridge.auth')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')

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

local e_download_config = errors.new_class('Config download failed')
local function download_config_handler(req)
    if not auth.authorize_request(req) then
        local err = e_download_config:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    local clusterwide_config = confapplier.get_active_config()
    if clusterwide_config == nil then
        local err = e_download_config:new("Cluster isn't bootsrapped yet")
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

local e_upload_config = errors.new_class('Config upload failed')
local e_decode_yaml = errors.new_class('Decoding YAML failed')
local function upload_config_handler(req)
    if not auth.authorize_request(req) then
        local err = e_upload_config:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    if confapplier.get_readonly() == nil then
        local err = e_upload_config:new("Cluster isn't bootsrapped yet")
        return http_finalize_error(409, err)
    end

    local req_body = req:read()
    local content_type = req.headers['content-type'] or ''
    local multipart, boundary = content_type:match('(multipart/form%-data); boundary=(.+)')
    if multipart == 'multipart/form-data' then
        -- RFC 2046 http://www.ietf.org/rfc/rfc2046.txt
        -- 5.1.1.  Common Syntax
        -- The boundary delimiter line is then defined as a line
        -- consisting entirely of two hyphen characters ("-", decimal value 45)
        -- followed by the boundary parameter value from the Content-Type header
        -- field, optional linear whitespace, and a terminating CRLF.
        --
        -- string.match takes a pattern, thus we have to prefix any characters
        -- that have a special meaning with % to escape them.
        -- A list of special characters is ().+-*?[]^$%
        local boundary_line = string.gsub('--'..boundary, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
        local _, form_body = req_body:match(
            boundary_line .. '\r\n' ..
            '(.-\r\n)' .. '\r\n' .. -- headers
            '(.-)' .. '\r\n' .. -- body
            boundary_line
        )
        req_body = form_body
    end

    local conf_new, err = nil
    if req_body == nil then
        err = e_upload_config:new('Request body must not be empty')
    else
        conf_new, err = e_decode_yaml:pcall(yaml.decode, req_body)
    end

    if err ~= nil then
        return http_finalize_error(400, err)
    elseif type(conf_new) ~= 'table' then
        err = e_upload_config:new('Config must be a table')
        return http_finalize_error(400, err)
    end

    log.warn('Config uploaded')

    local patch = {}

    local clusterwide_config_old = confapplier.get_active_config()
    for k, _ in pairs(clusterwide_config_old:get_plaintext()) do
        if not system_sections[k] then
            patch[k] = box.NULL
        end
    end

    for k, v in pairs(conf_new) do
        if system_sections[k] then
            local err = e_upload_config:new(
                "uploading system section %q is forbidden", k
            )
            return http_finalize_error(400, err)
        elseif type(conf_new[k .. '.yml']) ~= 'nil' then
            local err = e_upload_config:new(
                "ambiguous sections %q and %q", k, k .. '.yml'
            )
            return http_finalize_error(400, err)
        elseif v == nil or type(v) == 'string' then
            patch[k] = v
        else
            patch[k .. '.yml'] = yaml.encode(v)
        end
    end

    local ok, err = twophase.patch_clusterwide(patch)
    if ok == nil then
        return http_finalize_error(400, err)
    end

    return auth.render_response({status = 200})
end

local function init(httpd)

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
}
