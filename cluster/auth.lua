#!/usr/bin/env tarantool

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local clock = require('clock')
local fiber = require('fiber')
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
local confapplier = require('cluster.confapplier')
local cluster_cookie = require('cluster.cluster-cookie')

vars:new('enabled', false)
vars:new('callbacks', {})
vars:new('cookie_max_age', 30*24*3600) -- in seconds
vars:new('cookie_caching_time', 60) -- in seconds
local e_callback = errors.new_class('Auth callback failed')
local e_add_user = errors.new_class('Auth callback "add_user()" failed')
local e_get_user = errors.new_class('Auth callback "get_user()" failed')
local e_edit_user = errors.new_class('Auth callback "edit_user()" failed')
local e_list_users = errors.new_class('Auth callback "list_users()" failed')
local e_remove_user = errors.new_class('Auth callback "remove_user()" failed')
local e_check_password = errors.new_class('Auth callback "check_password()" failed')

local function set_enabled(enabled)
    checks('boolean')
    vars.enabled = enabled

    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return true
    end

    topology_cfg.auth = enabled
    local ok, err = confapplier.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return true
end

local function get_enabled()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return vars.enabled
    elseif topology_cfg.auth then
        return true
    end

    return false
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

local function get_cookie_uid(raw)
    if type(raw) ~= 'string' then
        return nil
    end

    local msg = digest.base64_decode(raw)
    if msg == nil then
        return nil
    end

    local cookie = msgpack.decode(msg) -- may raise
    if type(cookie) ~= 'table'
    or type(cookie.ts) ~= 'string'
    or type(cookie.uid) ~= 'string'
    or type(cookie.hmac) ~= 'string' then
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
    if diff <= 0 or diff >= vars.cookie_max_age then
        return nil
    end

    return cookie.uid
end

local function get_session_username()
    local fiber_storage = fiber.self().storage
    return fiber_storage['auth_session_username']
end

local function login(req)
    if vars.callbacks.check_password == nil then
        return {
            status = 200,
        }
    end

    local username = req:param('username')
    local password = req:param('password')

    local ok, err = e_check_password:pcall(function()
        if username == nil or password == nil then
            return false
        end

        local ok = vars.callbacks.check_password(username, password)
        if type(ok) ~= 'boolean' then
            local err = e_callback:new('check_password() must return boolean')
            return nil, err
        end
        return ok
    end)

    if ok then
        return {
            status = 200,
            headers = {
                ['set-cookie'] = string.format('lsid=%s; Max-Age=%d',
                    create_cookie(username), vars.cookie_max_age
                )
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
            ['set-cookie'] = 'lsid=""; Max-Age=-1'
        }
    }
end

local function coerce_user(user)
    if type(user) ~= 'table'
    or (type(user.username) ~= 'string')
    or (type(user.fullname) ~= 'string' and user.fullname ~= nil )
    or (type(user.email) ~= 'string' and user.email ~= nil ) then
        return nil
    end
    return {
        username = user.username,
        fullname = user.fullname,
        email = user.email,
    }
end

local function add_user(username, password, fullname, email)
    checks('string', 'string', '?string', '?string')
    if vars.callbacks.add_user == nil then
        return nil, e_callback:new('add_user() callback isn\'t set')
    end

    return e_add_user:pcall(function()
        local user, err = vars.callbacks.add_user(username, password, fullname, email)
        if not user then
            return nil, e_add_user:new(err)
        end

        user = coerce_user(user)
        if not user then
            local err = e_callback:new('add_user() must return a user object')
            return nil, err
        end

        return user
    end)
end

local function get_user(username)
    checks('string')
    if vars.callbacks.get_user == nil then
        return nil, e_callback:new('get_user() callback isn\'t set')
    end

    return e_get_user:pcall(function()
        local user, err = vars.callbacks.get_user(username)

        if not user then
            return nil, e_get_user:new(err)
        end

        user = coerce_user(user)
        if not user then
            local err = e_callback:new('get_user() must return a user object')
            return nil, err
        end

        return user
    end)
end

local function edit_user(username, password, fullname, email)
    checks('string', '?string', '?string', '?string')
    if vars.callbacks.edit_user == nil then
        return nil, e_callback:new('edit_user() callback isn\'t set')
    end

    return e_edit_user:pcall(function()
        local user, err = vars.callbacks.edit_user(username, password, fullname, email)

        if not user then
            return nil, e_edit_user:new(err)
        end

        user = coerce_user(user)
        if not user then
            local err = e_callback:new('edit_user() must return a user object')
            return nil, err
        end

        return user
    end)
end

local function list_users()
    if vars.callbacks.list_users == nil then
        return nil, e_callback:new('list_users() callback isn\'t set')
    end

    return e_list_users:pcall(function()
        local users, err = vars.callbacks.list_users()
        if not users then
            return nil, e_list_user:new(err)
        end

        local ret = {}
        local i = 1
        for _ in pairs(users) do
            local user = users[i]
            if not user then
                local err = e_callback:new('list_users() must return an array')
                return nil, err
            end
            user = coerce_user(user)
            if not user then
                local err = e_callback:new('list_users() must return array of user objects')
                return nil, err
            end
            ret[i] = user
            i = i + 1
        end

        return ret
    end)
end

local function remove_user(username)
    checks('string')
    if vars.callbacks.remove_user == nil then
        return nil, e_callback:new('remove_user() callback isn\'t set')
    end

    return e_remove_user:pcall(function()
        local user, err = vars.callbacks.remove_user(username)
        if not user then
            return nil, e_remove_user:new(err)
        end

        user = coerce_user(user)
        if not user then
            local err = e_callback:new('remove_user() must return a user object')
            return nil, err
        end

        return user
    end)
end

local function check_request(req)
    if vars.callbacks.check_password == nil then
        return true
    end

    local username
    local lsid = req:cookie('lsid')
    if lsid ~= nil then
        local ok, uid = pcall(get_cookie_uid, lsid)
        if ok and uid then
            username = uid
        end
    end

    if username and vars.callbacks.get_user ~= nil then
        local user = get_user(username)
        if not user then
            username = nil
        end
    end

    if username then
        local fiber_storage = fiber.self().storage
        fiber_storage['auth_session_username'] = username
        return true
    end

    if not get_enabled() then
        return true
    end

    return false
end

local function init(httpd)
    checks('table')

    httpd:route({
        path = '/login',
        method = 'POST'
    }, login)
    httpd:route({
        path = '/logout',
        method = 'POST'
    }, logout)

    return true
end

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

local function get_callbacks()
    return table.copy(vars.callbacks)
end

local function set_params(opts)
    checks({
        cookie_max_age = '?number',
        cookie_caching_time = '?number',
    })

    if opts ~= nil and opts.cookie_max_age ~= nil then
        vars.cookie_max_age = opts.cookie_max_age
    end

    if opts ~= nil and opts.cookie_caching_time ~= nil then
        vars.cookie_caching_time = opts.cookie_caching_time
    end

    return true
end

local function get_params()
    return {
        cookie_max_age = vars.cookie_max_age,
        cookie_caching_time = vars.cookie_caching_time,
    }
end

return {
    init = init,
    set_params = set_params,
    get_params = get_params,
    set_callbacks = set_callbacks,
    get_callbacks = get_callbacks,
    set_enabled = set_enabled,
    get_enabled = get_enabled,

    add_user = add_user,
    get_user = get_user,
    edit_user = edit_user,
    list_users = list_users,
    remove_user = remove_user,

    check_request = check_request,
    -- invalidate_session = invalidate_session,
    get_session_username = get_session_username,
}
