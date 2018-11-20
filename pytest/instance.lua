#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local http = require('http.server')
local cluster = require('cluster')

package.preload['mymodule'] = function()
    local state = nil
    return {
        role_name = 'myrole',
        get_state = function() return state end,
        init = function() state = 'initialized' end,
    }
end

local ok, err = xpcall(cluster.register_role, debug.traceback, 'mymodule')
if not ok then
    log.error('%s', err)
    os.exit(1)
end

local ok, err = xpcall(cluster.init, debug.traceback, {
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI'),
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

local http_port = os.getenv('HTTP_PORT')
local httpd = http.new(
    '0.0.0.0', tonumber(http_port),
    { log_requests = false }
)
local ok, err = cluster.webui.init(httpd)

if not ok then
    log.error('%s', err)
    os.exit(1)
end

httpd:start()
log.info('Listening HTTP on 0.0.0.0:%s', http_port)

_G.is_initialized = cluster.is_healthy

function get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
