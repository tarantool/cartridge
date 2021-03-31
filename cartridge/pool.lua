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

local utils = require('cartridge.utils')
local vars = require('cartridge.vars').new('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')

vars:new('connections', {})

local FormatURIError = errors.new_class('FormatURIError')
local NetboxConnectError = errors.new_class('NetboxConnectError')
local NetboxMapCallError = errors.new_class('NetboxMapCallError')
local NetboxCallError = errors.new_class('NetboxCallError')


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

    local conn = vars.connections[uri]
    if conn == nil
    or conn.state == 'error'
    or conn.state == 'closed'
    then
        -- concurrent part, won't yeild
        local _uri, err = format_uri(uri)
        if err ~= nil then
            return nil, err
        end

        conn, err = NetboxConnectError:pcall(netbox.connect,
            _uri, {wait_connected = false}
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


local function sync_connect(uri, deadline, out_chan)
    local timeout = deadline - fiber.clock()
    if timeout < 0 then
        timeout = 0
    end

    local conn, err = NetboxMapCallError:pcall(connect, uri, {wait_connected = timeout})
    out_chan:put({
        data = conn,
        err = err,
        uri = uri
    })
end

local function wait_future(uri, deadline, future, out_chan)
    local timeout = deadline - fiber.clock()
    if timeout < 0 then
        timeout = 0
    end

    -- wait_result behaviour:
    -- - may raise an error (if timeout ~= number or timeout < 0)
    -- - return nil, err as string:
    --     - if there is no result with fixed timeout (Timeout exceeded)
    --     - peer closed
    --     - error was raised in remote function
    -- - return res as array:
    --     - res[1] - result or nil
    --     - res[2] - error or nil (error maybe as object or string)
    local res, err = future:wait_result(timeout) -- wait_result(0) won't yeild
    local response = {uri = uri}
    if err ~= nil then
        response.err = NetboxCallError:new('%q: %s', uri, err)
    else
        local _res, _err = res[1], res[2]
        if _err ~= nil then
            if errors.is_error_object(_err) then
                _err.err = ('%q: %s'):format(uri, _err.err)
                _err.str = ('%s: %s'):format(_err.class_name, _err.err)
            else
                _err = NetboxCallError:new('%q: %s', uri, _err)
            end
            response.err = _err
        else
            response.data = _res
        end
    end
    future:discard()
    out_chan:put(response)
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
--   passed to `net.box` `conn:call()`
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
    local uri_map = {}
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

    local retmap = {}
    local errmap = {}
    local timeout = opts.timeout or 10
    local deadline = fiber.clock() + timeout

    local wait_conn_chan = fiber.channel(1)
    do -- connect stage performs in fibers
        for _, uri in ipairs(opts.uri_list) do
            local fib = fiber.new(sync_connect, uri, deadline, wait_conn_chan)
            fib:name('netbox_map_call_connect_worker')
        end
    end

    local count_futures = 0
    local wait_future_chan = fiber.channel(1)
    do -- perform netbox calls in main fiber and run wait_future in separate fiber
        for _ = 1, #opts.uri_list do
            local resp = wait_conn_chan:get()

            local uri = resp.uri
            local conn, err = resp.data, resp.err
            if err ~= nil then
                errmap[uri] = err
                goto continue
            end

            local future, err = errors.netbox_call(
                conn, fn_name, args, {is_async = true}
            )
            if err ~= nil then
                errmap[uri] = err
                goto continue
            end

            local fib = fiber.new(
                wait_future, uri, deadline, future, wait_future_chan
            )
            fib:name('netbox_map_call_future_worker')
            count_futures = count_futures + 1

            ::continue::
        end
        wait_conn_chan:close()
    end

    do -- gather results
        for _ = 1, count_futures do
            local resp = wait_future_chan:get()
            if resp.err ~= nil then
                errmap[resp.uri] = resp.err
            else
                retmap[resp.uri] = resp.data
            end
        end
        wait_future_chan:close()
    end

    if utils.table_count(errmap) == 0 then
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

return {
    connect = connect,
    format_uri = format_uri,
    map_call = map_call,
}
