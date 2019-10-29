#!/usr/bin/env tarantool

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

vars:new('locks', {})
vars:new('connections', {})
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
        return nil, errors.new(
            'FormatURIError',
            'Invalid URI %q', uri
        )
    end
    return uri_lib.format({
        host = parts.host,
        service = parts.service,
        login = cluster_cookie.username(),
        password = cluster_cookie.cookie()
    }, true)
end

local function _connect(uri, options)
    local conn, err = vars.connections[uri]

    if conn == nil or not conn:is_connected() then
        local _uri, _err = format_uri(uri)
        if _uri == nil then
            return nil, _err
        end

        conn, err = netbox.connect(_uri, options)
    end

    if not conn then
        return nil, err
    end

    vars.connections[uri] = conn
    if not conn:is_connected() then
        err = NetboxConnectError:new(
            '%q: %s', uri, conn.error
        )
        return nil, err
    end
    return conn
end

--- Connect a remote or get cached connection.
-- Connection is established using `net.box.connect()`.
-- @function connect
-- @tparam string uri
-- @tparam[opt] table opts
-- @return[1] `net.box` connection
-- @treturn[2] nil
-- @treturn[2] table Error description
local function connect(uri, options)
    checks('string', '?table')
    while vars.locks[uri] do
        fiber.sleep(0)
    end
    vars.locks[uri] = true
    local conn, err = NetboxConnectError:pcall(_connect, uri, options)
    vars.locks[uri] = false

    return conn, err
end

local function _pack_values(maps, uri, ...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        maps[i] = maps[i] or {}
        maps[i][uri] = v
    end
end

local function _gather_netbox_call(maps, uri, fn_name, args, opts)
    local conn, err = connect(uri)

    if conn == nil then
        _pack_values(maps, uri,
            nil, err
        )
        return
    end

    _pack_values(maps, uri,
        errors.netbox_call(conn, fn_name, args, opts)
    )
    return
end

--- Perform a remote call to multiple URIs and map results.
--
-- (**Added** in v1.1.0-29)
-- @function map_call
-- @local
--
-- @tparam string fn_name
-- @tparam ?table args
-- @tparam[opt] table opts
-- @tparam {string,...} opts.uri_list
--   array of URIs for performing remote call
-- @tparam ?number opts.timeout
--   passed to `net.box` `conn:call` options
--
-- @treturn {URI=value,...}
--   Call results mapping for every URI.
-- @treturn nil|{URI=error,...}
--   Errors mapping for every URI.
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
                ' (repetitions are prohibited)', 2
            )
        end
        uri_map[uri] = true
    end

    local maps = {}
    local fibers = {}
    for _, uri in pairs(opts.uri_list) do
        local fiber = fiber.new(
            _gather_netbox_call,
            maps, uri, fn_name, args,
            {timeout = opts.timeout}
        )
        fiber:name('netbox_call_map')
        fiber:set_joinable(true)
        fibers[uri] = fiber
    end

    for _, uri in pairs(opts.uri_list) do
        local ok, err = fibers[uri]:join()
        if not ok then
            _pack_values(maps, uri,
                nil, NetboxMapCallError:new(err)
            )
        end
    end

    return unpack(maps)
end

return {
    connect = connect,
    format_uri = format_uri,
    map_call = map_call,
}
