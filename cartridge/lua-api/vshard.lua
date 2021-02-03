--- Administration functions (vshard related).
--
-- @module cartridge.lua-api.vshard

local rpc = require('cartridge.rpc')
local confapplier = require('cartridge.confapplier')

--- Call `vshard.router.bootstrap()`.
-- This function distributes all buckets across the replica sets.
-- @function bootstrap_vshard
-- @treturn[1] boolean `true`
-- @treturn[2] nil
-- @treturn[2] table Error description
local function bootstrap_vshard()
    local state = confapplier.get_state()
    if state == 'Unconfigured' and rpc.is_proxy_call_possible() then
        local res, err = rpc.proxy_call('_G.__proxy_bootstrap_vshard')
        if err ~= nil then
            return nil, err
        end
        return res
    end
    return rpc.call('vshard-router', 'bootstrap')
end

_G.__proxy_bootstrap_vshard = bootstrap_vshard

return {
    bootstrap_vshard = bootstrap_vshard,
}
