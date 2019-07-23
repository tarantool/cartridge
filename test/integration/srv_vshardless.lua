#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

if not pcall(require, 'cluster.front-bundle') then
    -- to be loaded in development environment
    package.preload['cluster.front-bundle'] = function()
        return require('webui.build.bundle')
    end
end

local log = require('log')
local errors = require('errors')
local cluster = require('cluster')
errors.set_deprecation_handler(function(err)
    log.error('%s', err)
    os.exit(1)
end)

package.preload['mymodule'] = function()
    return {
        role_name = 'myrole',
        get_uuid = function()
            -- this function is used in pytest
            return box.info().uuid
        end,
    }
end

local ok, err = cluster.cfg({
    alias = os.getenv('TARANTOOL_ALIAS'),
    workdir = os.getenv('TARANTOOL_WORKDIR'),
    advertise_uri = os.getenv('TARANTOOL_ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('TARANTOOL_CLUSTER_COOKIE'),
    http_port = os.getenv('TARANTOOL_HTTP_PORT') or 8081,
    roles = {
        'mymodule',
    },
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy

function _G.get_uuid()
end
