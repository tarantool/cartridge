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
    local state = nil
    local master = nil
    local service_registry = require('cluster.service-registry')
    local httpd = service_registry.get('httpd')
    local validated = false

    if httpd ~= nil then
        httpd:route(
            {
                method = 'GET',
                path = '/custom-get',
                public = true,
            },
            function(_)
                return {
                    status = 200,
                    body = 'GET OK',
                }
            end
        )

        httpd:route(
            {
                method = 'POST',
                path = '/custom-post',
                public = true,
            },
            function(_)
                return {
                    status = 200,
                    body = 'POST OK',
                }
            end
        )
    end

    return {
        role_name = 'myrole',
        dependencies = {'mymodule-dependency'},
        get_state = function() return state end,
        is_master = function() return master end,
        validate_config = function()
            validated = true
            return true
        end,
        init = function(opts)
            assert(opts.is_master ~= nil)
            assert(validated,
                'Config was not validated prior to init()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            state = 'initialized'
        end,
        apply_config = function(_, opts)
            assert(opts.is_master ~= nil)
            assert(validated,
                'Config was not validated prior to apply_config()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            master = opts.is_master
            validated = false
        end,
        stop = function()
            state = 'stopped'
            validated = false
        end
    }
end

package.preload['mymodule-dependency'] = function()
    return {
        role_name = 'myrole-dependency',
    }
end

local ok, err = cluster.cfg({
    alias = os.getenv('TARANTOOL_ALIAS'),
    workdir = os.getenv('TARANTOOL_WORKDIR'),
    advertise_uri = os.getenv('TARANTOOL_ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('TARANTOOL_CLUSTER_COOKIE'),
    http_port = os.getenv('TARANTOOL_HTTP_PORT') or 8081,
    bucket_count = 3000,
    roles = {
        'cluster.roles.vshard-storage',
        'cluster.roles.vshard-router',
        'mymodule-dependency',
        'mymodule',
    },
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy

function _G.get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
