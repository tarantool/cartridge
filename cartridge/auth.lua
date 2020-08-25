--- Administrators authentication and authorization.
--
-- @module cartridge.auth

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local fiber = require('fiber')
local digest = require('digest')
local checks = require('checks')
local errors = require('errors')
local msgpack = require('msgpack')
local crypto = require('crypto')
json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
})

local vars = require('cartridge.vars').new('cartridge.auth')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
local cluster_cookie = require('cartridge.cluster-cookie')

vars:new('enabled', false)
vars:new('callbacks', {})

local DEFAULT_COOKIE_MAX_AGE = 3600*24*30 -- in seconds
local DEFAULT_COOKIE_RENEW_AGE = 3600*24 -- in seconds

local ADMIN_USER = {
    username = cluster_cookie.username(),
    fullname = 'Cartridge Administrator'
}

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

--- Check if unauthenticated access is forbidden.
-- (*Added* in v0.7)
--
-- @function get_enabled
-- @local
-- @treturn boolean enabled
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

--- Modify authentication params.
-- (*Changed* in v0.11)
--
-- Can't be used before the bootstrap.
-- Affects all cluster instances.
-- Triggers `cluster.config_patch_clusterwide`.
--
-- @function set_params
-- @within Configuration
-- @tparam table opts
-- @tparam ?boolean opts.enabled (*Added* in v0.11)
-- @tparam ?number opts.cookie_max_age
-- @tparam ?number opts.cookie_renew_age (*Added* in v0.11)
-- @treturn[1] boolean `true`
-- @treturn[2] nil
-- @treturn[2] table Error description
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

    return twophase.patch_clusterwide(patch)
end

--- Retrieve authentication params.
--
-- @function get_params
-- @within Configuration
-- @treturn AuthParams
local function get_params()
    local auth_cfg = confapplier.get_readonly('auth')

    --- Authentication params.
    -- @table AuthParams
    -- @within Configuration
    -- @tfield boolean enabled Wether unauthenticated access is forbidden
    -- @tfield number cookie_max_age Number of seconds until the authentication cookie expires
    -- @tfield number cookie_renew_age Update provided cookie if it's older then this age (in seconds)
    return {
        enabled = get_enabled(),
        cookie_max_age = auth_cfg and auth_cfg.cookie_max_age or DEFAULT_COOKIE_MAX_AGE,
        cookie_renew_age = auth_cfg and auth_cfg.cookie_renew_age or DEFAULT_COOKIE_RENEW_AGE,
    }
end

local function create_cookie(uid, version)
    checks('string', '?')
    local ts = tostring(fiber.time())
    local key = cluster_cookie.cookie()

    local msg = uid .. ts
    if version ~= nil then
        msg = msg .. tostring(version)
    end
    local cookie = {
        ts = ts,
        uid = uid,
        version = version,
        hmac = digest.base64_encode(
            crypto.hmac.sha512(key, msg),
            {nopad = true, nowrap = true, urlsafe = true}
        )
    }

    local raw = msgpack.encode(cookie)
    local lsid = digest.base64_encode(raw,
        {nopad = true, nowrap = true, urlsafe = true}
    )

    return string.format(
        'lsid=%q; Path=/; Max-Age=%d', lsid,
        get_params().cookie_max_age
    )
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
    local msg = cookie.uid .. cookie.ts
    if cookie.version ~= nil then
        msg = msg .. tostring(cookie.version)
    end
    local calc = digest.base64_encode(
        crypto.hmac.sha512(key, msg),
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

    if username == ADMIN_USER.username then
        local ok = password == cluster_cookie.cookie()
        if ok then
            return username
        else
            return nil
        end
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

--- Create session for current user.
--
-- Creates session for user with specified username and user version
-- or clear it if no arguments passed.
--
-- (**Added** in v2.2.0-43)
-- @function set_lsid_cookie
-- @within Authorizarion
-- @tparam table user
local function set_lsid_cookie(user)
    checks('?table')
    local fiber_storage = fiber.self().storage
    if user == nil then
        fiber_storage['http_session_set_cookie'] = 'lsid=""; Path=/; Max-Age=0'
    else
        fiber_storage['http_session_set_cookie'] = create_cookie(user.username, user.version)
    end
end

--- Get username for the current HTTP session.
--
-- (**Added** in v1.1.0-4)
-- @function get_session_username
-- @within Authorizarion
-- @treturn string|nil
local function get_session_username()
    return fiber.self().storage['http_session_username']
end

local function login(req)
    local username = req:param('username')
    local password = req:param('password')

    -- First check for built-in admin user
    if username == ADMIN_USER.username then
        if password == cluster_cookie.cookie() then
            return {
                status = 200,
                headers = {
                    ['set-cookie'] = create_cookie(username),
                }
            }
        else
            return {
                status = 403,
            }
        end
    end

    if vars.callbacks.check_password == nil then
        return {
            status = 403,
        }
    end

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
        local user_version
        if vars.callbacks.get_user ~= nil then
            local user = vars.callbacks.get_user(username)
            if user ~= nil then
                user_version = user.version
            end
        end

        return {
            status = 200,
            headers = {
                ['set-cookie'] = create_cookie(username, user_version),
            },
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
            ['set-cookie'] = 'lsid=""; Path=/; Max-Age=0'
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

    --- User information.
    -- @table UserInfo
    -- @within User management
    -- @tfield string username
    -- @tfield ?string fullname
    -- @tfield ?string email
    -- @tfield ?number version
    return {
        username = user.username,
        fullname = user.fullname,
        email = user.email,
        version = user.version,
    }
end

--- Trigger registered add_user callback.
--
-- The callback is triggered with the same arguments and must return
-- a table with fields conforming to `UserInfo`. Unknown fields are ignored.
--
-- @function add_user
-- @within User management
-- @tparam string username
-- @tparam string password
-- @tparam ?string fullname
-- @tparam ?string email
-- @treturn[1] UserInfo
-- @treturn[2] nil
-- @treturn[2] table Error description
local function add_user(username, password, fullname, email)
    checks('string', 'string', '?string', '?string')
    if username == ADMIN_USER.username then
        return nil, e_callback:new(
            "add_user() can't override integrated superuser '%s'",
            username
        )
    end

    if vars.callbacks.add_user == nil then
        return nil, e_callback:new("add_user() callback isn't set")
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
--
-- The callback is triggered with the same arguments and must return
-- a table with fields conforming to `UserInfo`. Unknown fields are ignored.
--
-- @function get_user
-- @within User management
-- @tparam string username
-- @treturn[1] UserInfo
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_user(username)
    checks('string')

    if username == ADMIN_USER.username then
        return coerce_user(ADMIN_USER)
    end

    if vars.callbacks.get_user == nil then
        return nil, e_callback:new("get_user() callback isn't set")
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
--
-- The callback is triggered with the same arguments and must return
-- a table with fields conforming to `UserInfo`. Unknown fields are ignored.
--
-- @function edit_user
-- @within User management
-- @tparam string username
-- @tparam ?string password
-- @tparam ?string fullname
-- @tparam ?string email
-- @treturn[1] UserInfo
-- @treturn[2] nil
-- @treturn[2] table Error description
local function edit_user(username, password, fullname, email)
    checks('string', '?string', '?string', '?string')
    if username == ADMIN_USER.username then
        return nil, e_callback:new(
            "edit_user() can't change integrated superuser '%s'",
            username
        )
    end

    if vars.callbacks.edit_user == nil then
        return nil, e_callback:new("edit_user() callback isn't set")
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

        local fiber_storage = fiber.self().storage
        if password ~= nil and fiber_storage['http_session_username'] == user.username then
            set_lsid_cookie(user)
        end
        return user
    end)
end

--- Trigger registered list_users callback.
--
-- The callback is triggered without any arguments. It must return
-- an array of `UserInfo` objects.
--
-- @function list_users
-- @within User management
-- @treturn[1] {UserInfo,...}
-- @treturn[2] nil
-- @treturn[2] table Error description
local function list_users()
    if vars.callbacks.list_users == nil then
        return {coerce_user(ADMIN_USER)}
    end

    return e_list_users:pcall(function()
        local users, err = vars.callbacks.list_users()
        if not users then
            return nil, e_list_users:new(err)
        end

        local ret = {coerce_user(ADMIN_USER)}
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
            ret[i+1] = user
            i = i + 1
        end

        return ret
    end)
end

--- Trigger registered remove_user callback.
--
-- The callback is triggered with the same arguments and must return
-- a table with fields conforming to `UserInfo`, which was removed.
-- Unknown fields are ignored.
--
-- @function remove_user
-- @within User management
-- @tparam string username
-- @treturn[1] UserInfo
-- @treturn[2] nil
-- @treturn[2] table Error description
local function remove_user(username)
    checks('string')

    if username == get_session_username() then
        return nil, e_remove_user:new('user can not remove himself')
    end

    if username == ADMIN_USER.username then
        return nil, e_callback:new(
            "remove_user() can't delete integrated superuser '%s'",
            username)
    end

    if vars.callbacks.remove_user == nil then
        return nil, e_callback:new("remove_user() callback isn't set")
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

--- Authorize an HTTP request.
--
-- Get username from cookies or basic HTTP authentication.
--
-- (**Added** in v1.1.0-4)
-- @function authorize_request
-- @within Authorizarion
-- @tparam table request
-- @treturn boolean Access granted
local function authorize_request(req)
    checks('table')
    local fiber_storage = fiber.self().storage

    local auth_cfg = get_params()
    local cookie_raw = req:cookie('lsid')
    local cookie_ts = 0
    local username = nil
    local cookie_version
    repeat
        local cookie, err = e_check_cookie:pcall(get_cookie_uid, cookie_raw)
        if cookie ~= nil and cookie.uid ~= nil then
            username = cookie.uid
            cookie_ts = cookie.ts
            cookie_version = cookie.version
            break
        elseif err then
            log.error('%s', err)
        end

        local uid, err = e_check_header:pcall(
            get_basic_auth_uid,
            req.headers['authorization']
        )
        if uid ~= nil then
            username = uid
            break
        elseif err then
            log.error('%s', err)
        end
    until true

    local user
    if username and vars.callbacks.get_user ~= nil then
        user = get_user(username)
        if not user then
            username = nil
        end
    end

    if cookie_version ~= nil then
        if user ~= nil and user.version ~= cookie_version then
            username = nil
        end
    end

    if username then
        fiber_storage['http_session_username'] = username

        if cookie_ts > 0
        and auth_cfg.cookie_renew_age >= 0
        and fiber.time() - cookie_ts > auth_cfg.cookie_renew_age
        then
            set_lsid_cookie(user)
        end

        return true
    elseif cookie_raw then
        set_lsid_cookie()
    end

    if not auth_cfg.enabled then
        return true
    else
        return false
    end
end

--- Render HTTP response.
--
-- Inject set-cookie headers into response in order to renew or reset
-- the cookie.
--
-- (**Added** in v1.1.0-4)
-- @function render_response
-- @within Authorizarion
-- @tparam table response
-- @treturn table The same response with cookies injected
local function render_response(resp)
    checks('table')
    local set_cookie = fiber.self().storage['http_session_set_cookie']

    if set_cookie then
        if resp.headers == nil then
            resp.headers = {}
        end

        if resp.headers['set-cookie'] == nil then
            resp.headers['set-cookie'] = set_cookie
        else
            resp.headers['set-cookie'] = resp.headers['set-cookie'] ..
                ',' .. set_cookie
        end
    end

    return resp
end

--- Initialize the authentication HTTP API.
--
-- Set up `login` and `logout` HTTP endpoints.
-- @function init
-- @local
local function init(httpd)
    checks('table')

    local function wipe_fiber_storage()
        local fiber_storage = fiber.self().storage
        fiber_storage['http_session_username'] = nil
        fiber_storage['http_session_set_cookie'] = nil
    end

    if httpd.hooks.before_dispatch == nil then
        httpd.hooks.before_dispatch = wipe_fiber_storage
    else
        local before_dispatch_original = httpd.hooks.before_dispatch
        httpd.hooks.before_dispatch = function(...)
            wipe_fiber_storage()
            return before_dispatch_original(...)
        end
    end

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
-- @local
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

--- Get authentication callbacks.
--
-- @function get_callbacks
-- @local
-- @treturn table callbacks
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

    authorize_request = authorize_request,
    render_response = render_response,
    get_session_username = get_session_username,

    set_lsid_cookie = set_lsid_cookie,
}
