#!/usr/bin/env tarantool

--- Administrators authentication and authorization.
--
-- @module cluster.auth

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
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

local DEFAULT_COOKIE_MAX_AGE = 3600*24*30 -- in seconds
local DEFAULT_COOKIE_RENEW_AGE = 3600*24 -- in seconds

local e_check_cookie = errors.new_class('Checking cookie failed')
local e_check_header = errors.new_class('Checking auth headers failed')
local e_callback = errors.new_class('Auth callback failed')
local e_add_user = errors.new_class('Auth callback "add_user()" failed')
local e_get_user = errors.new_class('Auth callback "get_user()" failed')
local e_edit_user = errors.new_class('Auth callback "edit_user()" failed')
local e_list_users = errors.new_class('Auth callback "list_users()" failed')
local e_remove_user = errors.new_class('Auth callback "remove_user()" failed')
local e_check_password = errors.new_class('Auth callback "check_password()" failed')

--- Allow or deny unauthenticated access to the administrator's page.
-- (*Changed* in v0.11)
--
-- This function affects only the current instance.
-- It can't be used after the cluster was bootstrapped.
-- To modify clusterwide config use `set_params` instead.
--
-- @function set_enabled
-- @local
-- @tparam boolean enabled
-- @treturn[1] boolean `true`
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_enabled(enabled)
    checks('boolean')
    if confapplier.get_readonly() ~= nil then
        return nil, errors.new('AuthSetEnabledError',
            'Cluster is already bootstrapped. Use cluster.auth_set_params' ..
            ' to modify clusterwide config'
        )
    end

    vars.enabled = enabled

    return true
end

local function get_enabled()
    if confapplier.get_readonly() == nil then
        return vars.enabled
    end

    local auth_cfg = confapplier.get_readonly('auth')
    if auth_cfg == nil then
        -- backward compatibility with clusterwide config v0.10
        return confapplier.get_readonly('topology').auth or false
    else
        return auth_cfg.enabled
    end
end

local function set_params(opts)
    checks({
        enabled = '?boolean',
        cookie_max_age = '?number',
        cookie_renew_age = '?number',
    })

    if confapplier.get_readonly() == nil then
        return nil, errors.new('AuthSetParamsError',
            "Cluster isn't bootstrapped yet"
        )
    end

    if opts == nil then
        return true
    end

    local auth_cfg = confapplier.get_deepcopy('auth')
    if auth_cfg == nil then
        -- backward compatibility with clusterwide config v0.10
        auth_cfg = {
            enabled = confapplier.get_readonly('topology').auth or false,
            cookie_max_age = DEFAULT_COOKIE_MAX_AGE,
        }
    end

    if opts.enabled ~= nil then
        auth_cfg.enabled = opts.enabled
    end

    if opts.cookie_max_age ~= nil then
        auth_cfg.cookie_max_age = opts.cookie_max_age
    end

    if opts.cookie_renew_age ~= nil then
        auth_cfg.cookie_renew_age = opts.cookie_renew_age
    end

    local patch = {
        auth = auth_cfg
    }

    if confapplier.get_readonly('topology').auth ~= nil then
        patch.topology = confapplier.get_deepcopy('topology')
        patch.topology.auth = nil
    end

    return confapplier.patch_clusterwide(patch)
end

local function get_params()
    local auth_cfg = confapplier.get_readonly('auth')
    return {
        enabled = get_enabled(),
        cookie_max_age = auth_cfg and auth_cfg.cookie_max_age or DEFAULT_COOKIE_MAX_AGE,
        cookie_renew_age = auth_cfg and auth_cfg.cookie_renew_age or DEFAULT_COOKIE_RENEW_AGE,
    }
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
    local ts = tostring(fiber.time())
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

    cookie.ts = tonumber(cookie.ts)
    if cookie.ts == nil then
        return nil
    end

    local diff = fiber.time() - cookie.ts
    if diff <= 0 or diff >= get_params().cookie_max_age then
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

    return cookie
end

local function get_basic_auth_uid(auth)
    if type(auth) ~= 'string' then
        return nil
    end

    local credentials = auth:match('^Basic (.+)$')
    if not credentials then
        return nil
    end

    local plaintext = digest.base64_decode(credentials)
    local username, password = unpack(plaintext:split(':', 1))
    if username == nil or password == nil then
        return nil
    end

    local ok = vars.callbacks.check_password(username, password)
    if type(ok) ~= 'boolean' then
        local err = e_callback:new('check_password() must return boolean')
        return nil, err
    elseif ok then
        return username
    else
        return nil
    end
end

--- Get username for the current HTTP session.
--
-- @function get_session_username
-- @treturn string or nil if no user is logged in
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
                    create_cookie(username),
                    get_params().cookie_max_age
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
            ['set-cookie'] = 'lsid=""; Max-Age=0'
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

--- Trigger registered add_user callback.
-- The callback is called with the same arguments
-- and must return a `user_object`.
-- @function add_user
-- @tparam string username
-- @tparam string password
-- @tparam ?string fullname
-- @tparam ?string email
-- @return[1] `user_object`
-- @treturn[2] nil
-- @treturn[2] table Error description
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

--- Trigger registered get_user callback.
-- The callback is called with the same arguments
-- and must return a `user_object`.
-- @function get_user
-- @tparam string username
-- @return[1] `user_object`
-- @treturn[2] nil
-- @treturn[2] table Error description
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

--- Trigger registered edit_user callback.
-- The callback is called with the same arguments
-- and must return a `user_object`.
-- @function edit_user
-- @tparam string username
-- @tparam ?string password
-- @tparam ?string fullname
-- @tparam ?string email
-- @return[1] `user_object`
-- @treturn[2] nil
-- @treturn[2] table Error description
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

--- Trigger registered list_users callback.
-- The callback must return an array of `user_object`s.
-- @function list_users
-- @return[1] array of `user_object`s
-- @treturn[2] nil
-- @treturn[2] table Error description
local function list_users()
    if vars.callbacks.list_users == nil then
        return nil, e_callback:new('list_users() callback isn\'t set')
    end

    return e_list_users:pcall(function()
        local users, err = vars.callbacks.list_users()
        if not users then
            return nil, e_list_users:new(err)
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

--- Trigger registered remove_user callback.
-- The callback is called with the same arguments
-- and must return the `user_object` removed.
-- @function remove_user
-- @tparam string username
-- @return[1] `user_object`
-- @treturn[2] nil
-- @treturn[2] table Error description
local function remove_user(username)
    checks('string')

    if username == get_session_username() then
        return nil, e_remove_user:new('user can not remove himself')
    end

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

local _response_mt = {
    __index = {
        finalize = function(self, resp)
            for k, v in pairs(resp) do
                if type(self[k]) == 'table'
                and type(v) == 'table'
                then
                    -- merge tables
                    for tk, tv in pairs(v) do
                        self[k][tk] = tv
                    end
                else
                    self[k] = v
                end
            end

            return self
        end
    },
}
--- Authorize an HTTP request.
--
-- Try to get username from cookies or basic HTTP authentication.
--
-- @function check_request
-- @param req An HTTP request
-- @treturn boolean Access granted
-- @treturn table HTTP response template
local function check_request(req)
    local fiber_storage = fiber.self().storage
    -- clean fiber storage to behave correctly
    -- when user logouts within keepalive session
    fiber_storage['auth_session_username'] = nil

    local resp = setmetatable({}, _response_mt)

    if vars.callbacks.check_password == nil then
        return true, resp
    end

    local auth_cfg = get_params()
    local cookie_raw = req:cookie('lsid')
    local cookie_ts = 0
    local username = nil
    repeat
        local cookie, err = e_check_cookie:pcall(get_cookie_uid, cookie_raw)
        if cookie ~= nil and cookie.uid ~= nil then
            username = cookie.uid
            cookie_ts = cookie.ts
            break
        elseif err then
            log.error('%s', err)
        end

        local uid, err = e_check_header:pcall(get_basic_auth_uid, req.headers['authorization'])
        if uid ~= nil then
            username = uid
            break
        elseif err then
            log.error('%s', err)
        end
    until true

    if username and vars.callbacks.get_user ~= nil then
        local user = get_user(username)
        if not user then
            username = nil
        end
    end

    if username then
        fiber_storage['auth_session_username'] = username

        if cookie_ts > 0
        and auth_cfg.cookie_renew_age >= 0
        and fiber.time() - cookie_ts > auth_cfg.cookie_renew_age
        then
            resp['headers'] = {
                ['set-cookie'] = string.format(
                    'lsid=%s; Max-Age=%d',
                    create_cookie(username),
                    auth_cfg.cookie_max_age
                )
            }
        end

        return true, resp
    elseif cookie_raw then
        resp['headers'] = {
            ['set-cookie'] = 'lsid=""; Max-Age=0'
        }
    end

    if not auth_cfg.enabled then
        return true, resp
    else
        return false, resp
    end
end

--- Initialize the authentication HTTP API.
--
-- @function init
-- @local
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

--- Set authentication callbacks.
--
-- @function set_callbacks
-- @tparam table callbacks
-- @tparam function callbacks.add_user
-- @tparam function callbacks.get_user
-- @tparam function callbacks.edit_user
-- @tparam function callbacks.list_users
-- @tparam function callbacks.remove_user
-- @tparam function callbacks.check_password
-- @treturn boolean `true`
local function set_callbacks(callbacks)
    checks({
        add_user = '?function',
        get_user = '?function',
        edit_user = '?function',
        list_users = '?function',
        remove_user = '?function',

        check_password = '?function',
    })

    vars.callbacks = callbacks or {}
    return true
end

local function get_callbacks()
    return table.copy(vars.callbacks)
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

    -- check_session = check_session,
    check_request = check_request,
    -- invalidate_session = invalidate_session,
    get_session_username = get_session_username,
}
