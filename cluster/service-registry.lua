#!/usr/bin/env tarantool

local checks = require('checks')
local vars = require('cluster.vars').new('cluster.service-registry')
vars:new('registry', {})

local function set(name, instance)
    checks('string', '?table')
    vars.registry[name] = instance
end

local function get(name)
    return vars.registry[name]
end

return {
    get = get,
    set = set,
}