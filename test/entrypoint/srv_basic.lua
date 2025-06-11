#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end
_G.__TEST = true
local log = require('log')
local errors = require('errors')
local cartridge = require('cartridge')
errors.set_deprecation_handler(function(err)
    log.error('Deprecated function was called')
    log.error('%s', err)
    os.exit(1)
end)

local frontend = package.loaded['frontend-core']
if frontend and frontend.set_variable then
    -- Compatibility tests run on cartridge 1.2.0
    -- which doesn't support it yet.
    frontend.set_variable('cartridge_refresh_interval', 500)
    frontend.set_variable('cartridge_stat_period', 2)
    frontend.set_variable('cartridge_hide_all_rw', false)
end

package.preload['VERSION'] = function()
    return 'app_version_test_value'
end

package.preload['mymodule'] = function()
    local state = nil
    local master = nil
    local service_registry = require('cartridge.service-registry')
    local httpd = service_registry.get('httpd')
    local validated = {}
    local master_switches = {}
    local leaders_history = {}

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
        get_master_switches = function() return master_switches end,
        get_leaders_history = function() return leaders_history end,
        validate_config = function()
            table.insert(validated, true)
            return true
        end,
        init = function(opts)
            assert(opts.is_master ~= nil)
            assert(#validated > 0,
                'Config was not validated prior to init()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            state = 'initialized'
            table.insert(master_switches, opts.is_master)
        end,
        apply_config = function(_, opts)
            collectgarbage()
                collectgarbage()
            assert(opts.is_master ~= nil)
            assert(#validated > 0,
                'Config was not validated prior to apply_config()'
            )
            if opts.is_master then
                assert(box.info().ro == false)
            end
            master = opts.is_master
            table.remove(validated, #validated)
            local failover = require('cartridge.failover')
            table.insert(leaders_history, failover.get_active_leaders())
        end,
        stop = function()
            state = 'stopped'
            table.remove(validated, #validated)
        end,

        -- rpc functions
        dog_goes = function() return "woof" end,
        throw = function(msg) error(msg, 2) end,
        push = function(x)
            box.session.push(x + 1)
            return true
        end,
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
    local log = require('log')
    return {
        role_name = 'myrole-permanent',
        permanent = true,
        get_role_name = function()
            return 'myrole-permanent'
        end,

        init = function(opts)
            log.info('--- init({is_master = %s})', opts.is_master)
        end,
        apply_config = function(_, opts)
            log.info('--- apply_config({is_master = %s})', opts.is_master)
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

local roles_reload_allowed = nil
if not os.getenv('TARANTOOL_FORBID_HOTRELOAD') then
    roles_reload_allowed = true
end

local enable_failover_suppressing = nil
if os.getenv('TARANTOOL_SUPPRESS_FAILOVER') then
    enable_failover_suppressing = true
end

local enable_synchro_mode = true
if os.getenv('TARANTOOL_DISABLE_SYNCHRO_MODE') then
    enable_synchro_mode = nil
end

local rebalancer_mode = os.getenv('TARANTOOL_REBALANCER_MODE')

local disable_errstack = nil
if os.getenv('TARANTOOL_DISABLE_ERRSTACK') then
    disable_errstack = true
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
    roles_reload_allowed = roles_reload_allowed,
    enable_failover_suppressing = enable_failover_suppressing,
    enable_synchro_mode = enable_synchro_mode,
    -- Compatibility tests run on cartridge 1.2.0
    -- which doesn't support it yet.
    upload_prefix = package.loaded['cartridge.upload'] and '../upload',
    disable_errstack = disable_errstack,
    rebalancer_mode = rebalancer_mode,
},
{
    log = '',
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
