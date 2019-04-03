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


local auth = require('cluster.auth')
local confapplier = require('cluster.confapplier')

local function http_finalize_error(http_code, err)
    log.error(tostring(err))
    return {
        status = http_code,
        headers = {
            ['content-type'] = "application/json",
        },
        body = json.encode(err),
    }
end

local e_download_config = errors.new_class('Config download failed')
local function download_config_handler(req)
    if not auth.check_request(req) then
        local err = e_download_config:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    local conf = confapplier.get_deepcopy()
    if conf == nil then
        local err = e_download_config:new('Cluster isn\'t bootsrapped yet')
        return http_finalize_error(409, err)
    end

    conf.topology = nil
    conf.vshard = nil

    return {
        status = 200,
        headers = {
            ['content-type'] = "application/yaml",
            ['content-disposition'] = 'attachment; filename="config.yml"',
        },
        body = yaml.encode(conf)
    }
end

local e_upload_config = errors.new_class('Config upload failed')
local e_decode_yaml = errors.new_class('Decoding YAML failed')
local function upload_config_handler(req)
    if not auth.check_request(req) then
        local err = e_upload_config:new('Unauthorized')
        return http_finalize_error(401, err)
    end

    if confapplier.get_readonly() == nil then
        local err = e_upload_config:new('Cluster isn\'t bootsrapped yet')
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


    local conf, err = nil
    if req_body == nil then
        err = e_upload_config:new('Request body must not be empty')
    else
        conf, err = e_decode_yaml:pcall(yaml.decode, req_body)
    end

    if err ~= nil then
        return http_finalize_error(400, err)
    elseif type(conf) ~= 'table' then
        err = e_upload_config:new('Config must be a table')
        return http_finalize_error(400, err)
    elseif next(conf) == nil then
        err = e_upload_config:new('Config must not be empty')
        return http_finalize_error(400, err)
    end

    log.warn('Config uploaded')

    local ok, err = confapplier.patch_clusterwide(conf)
    if ok == nil then
        return http_finalize_error(400, err)
    end

    return { status = 200 }
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
