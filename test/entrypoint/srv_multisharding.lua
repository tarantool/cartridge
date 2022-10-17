#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end
_G.__TEST = true

local log = require('log')
local errors = require('errors')
local cartridge = require('cartridge')
errors.set_deprecation_handler(function(err)
    log.error('%s', err)
    os.exit(1)
end)

local ok, err = cartridge.cfg({
    bucket_count = nil,
    vshard_groups = {
        -- both notations are valid
        ['cold'] = {bucket_count = 2000},
        'hot',
    },
    roles = {
        'cartridge.roles.vshard-storage',
        'cartridge.roles.vshard-router',
    },
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
