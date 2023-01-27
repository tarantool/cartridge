--- Connection pool.
--
-- Reuse tarantool net.box connections with ease.
--
-- @module cartridge.pool

local uri_lib = require('uri')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')

local vars = require('cartridge.vars').new('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')

vars:new('connections', {})
vars:new('options', {
    MAP_CALL_TIMEOUT = 10,
})

vars:new('sslparams', {})

local FormatURIError = errors.new_class('FormatURIError')
local NetboxConnectError = errors.new_class('NetboxConnectError')
local NetboxMapCallError = errors.new_class('NetboxMapCallError')

--- Enrich URI with credentials.
-- Suitable to connect other cluster instances.
--
-- @function format_uri
-- @local
-- @tparam string uri `host:port`
-- @treturn string `username:password@host:port`
local function format_uri(uri)
    local parts = uri_lib.parse(uri)
    if parts == nil then
        return nil, FormatURIError:new('Invalid URI %q', uri)
    elseif parts.service == nil then
        return nil, FormatURIError:new('Invalid URI %q (missing port)', uri)
    end
    return uri_lib.format({
        host = parts.host,
        service = parts.service,
        login = cluster_cookie.username(),
        password = cluster_cookie.cookie()
    }, true)
end

--- Connect a remote or get cached connection.
-- Connection is established using `net.box.connect()`.
-- @function connect
-- @tparam string uri
-- @tparam[opt] table opts
-- @tparam ?boolean|number opts.wait_connected
--   by default, connection creation is blocked until the 
--   connection is established, but passing `wait_connected=false` 
--   makes it return immediately. Also, passing a timeout makes it 
--   wait before returning (e.g. `wait_connected=1.5` makes it wait 
--   at most 1.5 seconds).
-- @tparam ?number opts.fetch_schema Fetch schema from tarantool instances
-- @tparam ?number opts.connect_timeout (*deprecated*)
--   Use `wait_connected` instead
-- @param opts.user (*deprecated*) don't use it
-- @param opts.password (*deprecated*) don't use it
-- @param opts.reconnect_after (*deprecated*) don't use it
-- @return[1] `net.box` connection
-- @treturn[2] nil
-- @treturn[2] table Error description
local function connect(uri, opts)
    opts = opts or {}
    checks('string', {
        wait_connected = '?boolean|number',
        fetch_schema = '?boolean',
        user = '?string', -- deprecated
        password = '?string', -- deprecated
        reconnect_after = '?number', -- deprecated
        connect_timeout = '?number', -- deprecated
    })

    if opts.user ~= nil or opts.password ~= nil then
        errors.deprecate(
            'Options "user" and "password" are useless in pool.connect,' ..
            ' they never worked as intended and will never do'
        )
    end
    if opts.reconnect_after ~= nil then
        errors.deprecate(
            'Option "reconnect_after" is useless in pool.connect,' ..
            ' it never worked as intended and will never do'
        )
    end

    if opts.fetch_schema == nil then
        opts.fetch_schema = false
    end

    local conn = vars.connections[uri]
    if conn == nil
    or conn.state == 'error'
    or conn.state == 'closed'
    or conn.space == nil and opts.fetch_schema
    then
        -- concurrent part, won't yeild
        local _uri, err = format_uri(uri)
        if err ~= nil then
            return nil, err
        end

        if vars.sslparams.transport == 'ssl' then
            _uri = {uri=_uri,
                params={
                    transport=vars.sslparams.transport,
                    ssl_cert_file=vars.sslparams.ssl_cert_file,
                    ssl_key_file=vars.sslparams.ssl_key_file,
                    ssl_password=vars.sslparams.ssl_password,
                }}
        end

        conn, err = NetboxConnectError:pcall(netbox.connect,
            _uri, {wait_connected = false, fetch_schema = opts.fetch_schema}
        )
        if err ~= nil then
            return nil, err
        end

        vars.connections[uri] = conn
    end

    local wait_connected
    if opts.connect_timeout ~= nil then
        errors.deprecate(
            'Option "connect_timeout" is useless in pool.connect,' ..
            ' use "wait_connected" instead'
        )
        wait_connected = opts.connect_timeout
    end

    if type(opts.wait_connected) == 'number' then
        wait_connected = opts.wait_connected
    elseif opts.wait_connected == false then
        return conn
    end

    local ok = conn:wait_connected(wait_connected)
    if not ok then
        return nil, NetboxConnectError:new('%q: %s',
            uri, conn.error or "Connection not established (yet)"
        )
    end

    return conn
end

local function _gather_netbox_call(
    fiber_storage,
    retmap, errmap,
    conn, uri,
    fn_name, args,
    deadline
)
    local self_storage = fiber.self().storage
    for k, v in pairs(fiber_storage) do
        self_storage[k] = v
    end

    local ret, err = errors.netbox_call(conn, fn_name, args, {
        timeout = deadline - fiber.clock()
    })
    retmap[uri] = ret
    errmap[uri] = err
end

--- Perform a remote call to multiple URIs and map results.
--
-- (**Added** in v1.2.0-17)
-- @function map_call
-- @local
--
-- @tparam string fn_name
-- @tparam[opt] table args
--   function arguments
-- @tparam[opt] table opts
-- @tparam {string,...} opts.uri_list
--   array of URIs for performing remote call
-- @tparam ?number opts.timeout
--   passed to `net.box` `conn:call()` (unit: seconds, default: 10)
--
-- @treturn {URI=value,...}
--   Call results mapping for every URI.
-- @treturn[opt] table
--   United error object, gathering errors for every URI that failed.
local function map_call(fn_name, args, opts)
    checks('string', '?table', {
        uri_list = 'table',
        timeout = '?', -- for net.box.call
    })

    local i = 0
    local uri_map = table.new(0, #opts.uri_list)
    for _, _ in pairs(opts.uri_list) do
        i = i + 1
        local uri = opts.uri_list[i]
        if type(uri) ~= 'string' then
            error('bad argument opts.uri_list' ..
                ' to ' .. (debug.getinfo(1, 'nl').name or 'map_call') ..
                ' (contiguous array of strings expected)', 2
            )
        end
        if uri_map[uri] then
            error('bad argument opts.uri_list' ..
                ' to ' .. (debug.getinfo(1, 'nl').name or 'map_call') ..
                ' (duplicates are prohibited)', 2
            )
        end
        uri_map[uri] = true
    end

    local retmap, errmap = {}, {}
    local fibers = table.new(0, #opts.uri_list)
    local futures = table.new(0, #opts.uri_list)

    local timeout = opts.timeout or vars.options.MAP_CALL_TIMEOUT
    local deadline = fiber.clock() + timeout

    for _, uri in ipairs(opts.uri_list) do
        local conn, err = connect(uri, {wait_connected = false})
        if conn == nil then
            errmap[uri] = err
        elseif conn:is_connected() then
            local future, err = errors.netbox_call(
                conn, fn_name, args, {is_async = true}
            )
            futures[uri] = future
            errmap[uri] = err
        else
            -- We can't do an async request unless conn:is_connected().
            -- And we can't block the main fiber to wait when the
            -- connection is established. That's why we start new
            -- fibers. Otherwise, it'll affect other calls and we risk
            -- catching unnecessary timeouts.
            local fiber = fiber.new(_gather_netbox_call,
                fiber.self().storage,
                retmap, errmap,
                conn, uri,
                fn_name, args,
                deadline
            )
            fiber:name('netbox_map_call')
            fiber:set_joinable(true)
            fibers[uri] = fiber
        end
    end

    for uri, fiber in pairs(fibers) do
        local ok, err = fiber:join()
        if not ok then
            errmap[uri] = NetboxMapCallError:new(err)
        end
    end

    for uri, future in pairs(futures) do
        local timeout = deadline - fiber.clock()
        if timeout < 0 then
            timeout = 0
        end

        local ret, err = errors.netbox_wait_async(future, timeout)
        retmap[uri] = ret
        errmap[uri] = err
        future:discard()
    end

    if next(errmap) == nil then
        return retmap
    end

    local err_classes = {}
    for _, v in pairs(errmap) do
        if v.class_name then
            err_classes[v.class_name] = v
        end
    end

    local united_error = NetboxMapCallError:new('')
    local united_error_err = {}
    local united_error_str = {}
    for _, v in pairs(err_classes) do
        table.insert(united_error_err, v.err)
        table.insert(united_error_str, string.format('* %s', v))
    end

    united_error.err = table.concat(united_error_err, '\n')
    united_error.str = string.format("%s: %s:\n%s",
        united_error.class_name,
        'multiple errors occured',
        table.concat(united_error_str, '\n')
    )
    united_error.stack = nil
    united_error.suberrors = errmap

    local __index = table.copy(errmap)
    __index.tostring = NetboxMapCallError.tostring
    local instance_mt = {
        class_name = NetboxMapCallError.class_name,
        __tostring = NetboxMapCallError.tostring,
        __index = __index,
    }
    setmetatable(united_error, instance_mt)

    return retmap, united_error
end


local function change_port(uri, new_port)
    local parts = uri_lib.parse(uri)
    if parts == nil then
        return nil, FormatURIError:new('Invalid URI %q', uri)
    elseif parts.service == nil then
        return nil, FormatURIError:new('Invalid URI %q (missing port)', uri)
    end
    return uri_lib.format({
        host = parts.host,
        service = tostring(new_port),
        login = cluster_cookie.username(),
        password = cluster_cookie.cookie()
    }, true)
end

local function init(sslparams)
    vars.sslparams = sslparams
end

return {
    connect = connect,
    format_uri = format_uri,
    map_call = map_call,
    change_port = change_port,
    init = init,
}
