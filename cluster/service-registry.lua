#!/usr/bin/env tarantool

local vars = require('cluster.vars').new('cluster.service-registry')
vars:new('registry', {})

local function set(name, instance)
    checks('string', 'table')
    if vars.registry[name] ~= nil then
        assert(
            vars.registry[name] == instance,
            "Service reinitialization is not implemented yet"
        )
        -- TODO release old instance ???
        -- how? why?
    end
    vars.registry[name] = instance
end

local function get(name)
    return vars.registry[name]
end

return {
    get = get,
    set = set,
}