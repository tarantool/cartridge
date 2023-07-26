#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local errors = require('errors')
local cartridge = require('cartridge')
errors.set_deprecation_handler(function(err)
    log.error('Deprecated function was called')
    log.error('%s', err)
    os.exit(1)
end)

package.preload['no-auth'] = function()
    return {}
end

local ok, err = cartridge.cfg({
    roles = {},
    auth_backend_name = 'no-auth',
},
{
    log = '',
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cartridge.is_healthy
