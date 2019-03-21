#!/usr/bin/env tarantool

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local clock = require('clock')
local digest = require('digest')
local checks = require('checks')
local errors = require('errors')
local msgpack = require('msgpack')
json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
})

local vars = require('cluster.vars').new('cluster.auth')
local cluster_cookie = require('cluster.cluster-cookie')

vars:new('callbacks')
vars:new('http_handler')
local e_callback = errors.new_class('Auth callback failed')
local COOKIE_LIFE_SEC = 30*24*3600 -- 30 days

local function set_callbacks(callbacks)
    checks({
        add_user = '?function',
        get_user = '?function',
        edit_user = '?function',
        list_users = '?function',
        remove_user = '?function',
        check_password = '?function',
    })

    vars.callbacks = table.copy(callbacks) or {}
    return true
end

local function hmac(hashfun, blocksize, key, message)
    checks('function', 'number', 'string', 'string')
    local pkey = {key:byte(1, #key)}

    for i = #key + 1, blocksize do
        pkey[i] = 0x00
    end

    local ipad = table.copy(pkey)
    for i = 1, #ipad do
        ipad[i] = bit.bxor(0x36, ipad[i])
    end

    local opad = table.copy(pkey)
    for i = 1, #opad do
        opad[i] = bit.bxor(0x5c, opad[i])
    end

    ipad = string.char(unpack(ipad))
    opad = string.char(unpack(opad))

    return hashfun(opad .. hashfun(ipad .. message))
end

local function create_cookie(uid)
    checks('string')
    local ts = tostring(clock.time())
    local key = cluster_cookie.cookie()

    local cookie = {
        ts = ts,
        uid = uid,
        hmac = digest.base64_encode(
            hmac(digest.sha512, 128, key, uid .. ts),
            {nopad = true, nowrap = true, urlsafe = true}
        )
    }

    local raw = msgpack.encode(cookie)
    return digest.base64_encode(raw, {nopad = true, nowrap = true, urlsafe = true})
end

local function verify_cookie(raw)
    checks('?string')

    if raw == nil then
        return nil
    end

    local msg = digest.base64_decode(raw)
    if msg == nil then
        return nil
    end

    local cookie = msgpack.decode(msg)
    if cookie == nil or type(cookie) ~= 'table' then
        return nil
    end

    if cookie.ts == nil
    or cookie.uid == nil
    or cookie.hmac == nil then
        return nil
    end

    local key = cluster_cookie.cookie()
    local calc = digest.base64_encode(
        hmac(digest.sha512, 128, key, cookie.uid .. cookie.ts),
        {nopad = true, nowrap = true, urlsafe = true}
    )

    if calc ~= cookie.hmac then
        return nil
    end

    local diff = clock.time() - tonumber(cookie.ts)
    if diff <= 0 or diff >= COOKIE_LIFE_SEC then
        return nil
    end

    return e_callback:pcall(vars.get_user, cookie.uid)
end

local function check_request(req)
    if vars.check_password == nil then
        return true
    end

    local lsid = req:cookie('lsid')
    if verify_cookie(lsid) then
        return true
    end

    return false
end

local function login(req)
    if vars.check_password == nil then
        return {
            status = 200,
        }
    end

    local username = req:param('username')
    local password = req:param('password')

    local ok, err = e_callback:pcall(function()
        local ok = vars.check_password(username, password)
        e_callback:assert(
            type(ok) == 'boolean',
            'check_password() must return boolean'
        )
        return ok
    end)

    if ok then
        return {
            status = 200,
            headers = {
                ['set-cookie'] = 'lsid=' .. create_cookie(username) .. '; Expires=+1m'
            }
        }
    elseif err ~= nil then
        log.error('%s', err)
        return {
            status = 500,
            body = tostring(err),
        }
    else
        return {
            status = 403,
        }
    end
end

local function logout(_)
    return {
        status = 200,
        headers = {
            ['set-cookie'] = 'lsid=""; Expires="Thu, 01 Jan 1970 00:00:00 GMT"'
        }
    }
end

local function cfg(httpd)
    httpd:route({
        path = '/login',
        method = 'POST'
    }, login)
    httpd:route({
        path = '/logout',
        method = 'GET'
    }, logout)

    return true
end

return {
    cfg = cfg,
    set_callbacks = set_callbacks,

    check_request = check_request,
}
