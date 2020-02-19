#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local errors = require('errors')
local cartridge = require('cartridge')
errors.set_deprecation_handler(function(err)
    log.error('%s', err)
    os.exit(1)
end)

package.preload['mymodule'] = function()
    local state = nil
    local master = nil
    local service_registry = require('cartridge.service-registry')
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
        dependencies = {
            'mymodule-dependency',
            'mymodule-hidden',
        },
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
        end,

        -- rpc functions
        dog_goes = function() return "woof" end,
        throw = function(msg) error(msg, 2) end,
    }
end

package.preload['mymodule-dependency'] = function()
    return {
        role_name = 'myrole-dependency',

        -- rpc functions
        cat_goes = function() return "meow" end,
    }
end

package.preload['mymodule-permanent'] = function()
    return {
        role_name = 'myrole-permanent',
        permanent = true,
        get_role_name = function()
            return 'myrole-permanent'
        end,

        -- rpc functions
        cow_goes = function() return "moo" end,
    }
end

package.preload['mymodule-hidden'] = function()
    return {
        role_name = 'myrole-hidden',
        hidden = true,
        get_role_name = function()
            return 'myrole-hidden'
        end,

        -- rpc functions
        what_does_the_fox_say = function() return box.info.uuid end,
    }
end

local webui_blacklist = os.getenv('TARANTOOL_WEBUI_BLACKLIST')
if webui_blacklist ~= nil then
    webui_blacklist = string.split(webui_blacklist, ':')
end

local ok, err = errors.pcall('CartridgeCfgError', cartridge.cfg, {
    advertise_uri = 'localhost:3301',
    http_port = 8081,
    bucket_count = 3000,
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
        'mymodule-dependency',
        'mymodule-permanent',
        'mymodule-hidden',
        'mymodule',
    },
    webui_blacklist = webui_blacklist,
})
if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cartridge.is_healthy

function _G.get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
