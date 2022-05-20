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

local ok, err = errors.pcall('CartridgeCfgError', cartridge.cfg, {
    advertise_uri = 'localhost:3301',
    http_port = 8081,
    bucket_count = 3000,
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
        'test.roles.api',
        'test.roles.storage',
    },
})
if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G['2pc_count'] = 0

require('cartridge.twophase').on_patch(function()
    _G['2pc_count'] = _G['2pc_count'] + 1
end)
