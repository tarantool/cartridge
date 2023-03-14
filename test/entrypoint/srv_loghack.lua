#!/usr/bin/env tarantool

local require_original = require
rawset(_G, 'require', function(name)
    local module = require_original(name)
    if name == 'log' then
        module.warn = function(...)
            if rawget(_G, '__log_warn') == nil then
                rawset(_G, '__log_warn', {})
            end
            table.insert(_G.__log_warn, string.format(...))
        end
        module.error = function(...)
            if rawget(_G, '__log_error') == nil then
                rawset(_G, '__log_error', {})
            end
            table.insert(_G.__log_error, string.format(...))
        end
    end
    return module
end)

local helpers = require('test.helper')
dofile(helpers.entrypoint('srv_basic'))
