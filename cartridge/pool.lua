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
local e_connect = errors.new_class('Pool connect failed')

--- Enrich URI with credentials.
-- Suitable to connect other cluster instances.
--
-- @function format_uri
-- @local
-- @tparam string uri `host:port`
-- @treturn string `username:password@host:port`
local function format_uri(uri)
    local uri = uri_lib.parse(uri)
    return uri_lib.format({
        host = uri.host,
        service = uri.service,
        login = cluster_cookie.username(),
        password = cluster_cookie.cookie()
    }, true)
end

local function _connect(uri, options)
    local conn, err = vars.connections[uri]

    if conn == nil or not conn:is_connected() then
        conn, err = e_connect:pcall(netbox.connect, format_uri(uri), options)
    end

    if not conn then
        return nil, err
    end

    vars.connections[uri] = conn
    if not conn:is_connected() then
        err = e_connect:new('%q: %s', uri, conn.error)
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
    local conn, err = e_connect:pcall(_connect, uri, options)
    vars.locks[uri] = false

    return conn, err
end

return {
    connect = connect,
    format_uri = format_uri,
}
