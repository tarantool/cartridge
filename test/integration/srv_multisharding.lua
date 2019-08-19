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

local ok, err = cluster.cfg({
    bucket_count = nil,
    vshard_groups = {
        -- both notations are valid
        ['cold'] = {bucket_count = 2000},
        'hot',
    },
    roles = {
        'cluster.roles.vshard-storage',
        'cluster.roles.vshard-router',
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
