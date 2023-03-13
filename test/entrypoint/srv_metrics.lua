#!/usr/bin/env tarantool

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/test/entrypoint/srv_basic.lua

require('strict').on()

local log = require('log')
local errors = require('errors')
local cartridge = require('cartridge')
errors.set_deprecation_handler(function(err)
    log.error('%s', err)
    os.exit(1)
end)

local ok, err = errors.pcall('CartridgeCfgError', cartridge.cfg, {
    roles = {
        'cartridge.roles.metrics',
    },
    roles_reload_allowed = true,
})
if not ok then
    log.error('%s', err)
    os.exit(1)
end

local metrics = require('cartridge.roles.metrics')
metrics.set_export({
    {
        path = '/health',
        format = 'health'
    },
    {
        path = '/metrics',
        format = 'json'
    },
})
