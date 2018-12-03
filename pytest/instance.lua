#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local cluster = require('cluster')

package.preload['mymodule'] = function()
    local state = nil
    return {
        role_name = 'myrole',
        get_state = function() return state end,
        init = function() state = 'initialized' end,
    }
end

local ok, err = cluster.cfg({
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
    http_port = os.getenv('HTTP_PORT') or 8081,
    roles = {
        'mymodule'
    },
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy

function get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
