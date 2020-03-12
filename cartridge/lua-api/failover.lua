--- Administration functions (failover related).
--
-- @module cartridge.lua-api.failover

local checks = require('checks')
local errors = require('errors')

local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')

local EditTopologyError = errors.new_class('Editing cluster topology failed')

--- Get current failover state.
-- @function get_failover_enabled
local function get_failover_enabled()
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return false
    end
    return topology_cfg.failover or false
end

--- Enable or disable automatic failover.
-- @function set_failover_enabled
-- @tparam boolean enabled
-- @treturn[1] boolean New failover state
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_failover_enabled(enabled)
    checks('boolean')
    local topology_cfg = confapplier.get_deepcopy('topology')
    if topology_cfg == nil then
        return nil, EditTopologyError:new('Not bootstrapped yet')
    end
    topology_cfg.failover = enabled

    local ok, err = twophase.patch_clusterwide({topology = topology_cfg})
    if not ok then
        return nil, err
    end

    return topology_cfg.failover
end

return {
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,
}
