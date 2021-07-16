--- Inter-role interaction.
--
-- These functions make
-- different roles interact with each other.
--
-- The registry stores initialized modules
-- and accesses them within the one and only current instance.
-- For cross-instance access, use the `cartridge.rpc` module.
-- @module cartridge.service-registry

local checks = require('checks')
local vars = require('cartridge.vars').new('cartridge.service-registry')
vars:new('registry', {})

--- Put a module into registry or drop it.
-- This function typically doesn't need to be called explicitly, the
-- cluster automatically sets all the initialized roles.
--
-- @function set
-- @tparam string module_name
-- @tparam nil|table instance
-- @treturn nil
local function set(name, instance)
    checks('string', '?table')
    vars.registry[name] = instance
end

--- Get a module from registry.
--
-- @function get
-- @tparam string module_name
-- @treturn[1] nil
-- @treturn[2] table instance
local function get(name)
    return vars.registry[name]
end

return {
    get = get,
    set = set,
}
