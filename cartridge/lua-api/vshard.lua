--- Administration functions (vshard related).
--
-- @module cartridge.lua-api.vshard

local rpc = require('cartridge.rpc')
local errors = require('errors')
local confapplier = require('cartridge.confapplier')
local vshard_utils = require('cartridge.vshard-utils')

local VshardApiError = errors.new_class('vshard api error')

local function get_config()
    local result = {}
    local conf = confapplier.get_readonly()
    if conf == nil then
        error(VshardApiError:new('not bootstrapped'))
    end
    local vshard_groups
    if conf.vshard_groups == nil then
        vshard_groups = {default = conf.vshard}
    else
        vshard_groups = conf.vshard_groups
    end

    for group_name, _ in pairs(vshard_groups) do
        local vshard_cfg = vshard_utils.get_vshard_config(group_name, conf)
        result[group_name] = vshard_cfg
    end
    return result, nil
end

rawset(_G, 'cartridge_vshard_get_config', get_config)

--- Call `vshard.router.bootstrap()`.
-- This function distributes all buckets across the replica sets.
-- @function bootstrap_vshard
-- @treturn[1] boolean `true`
-- @treturn[2] nil
-- @treturn[2] table Error description
local function bootstrap_vshard()
    return rpc.call('vshard-router', 'bootstrap')
end

return {
    bootstrap_vshard = bootstrap_vshard,
}
