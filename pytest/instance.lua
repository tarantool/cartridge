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
local cluster = require('cluster')

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
            function(req)
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
            function(req)
                return {
                    status = 200,
                    body = 'POST OK',
                }
            end
        )
    end

    return {
        role_name = 'myrole',
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
            state = 'initialized'
        end,
        apply_config = function(_, opts)
            assert(validated,
                'Config was not validated prior to apply_config()'
            )
            master = opts.is_master
            validated = false
        end,
        stop = function()
            state = 'stopped'
            validated = false
        end
    }
end

local ok, err = cluster.cfg({
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
    bucket_count = 3000,
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
