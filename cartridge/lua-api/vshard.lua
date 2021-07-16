--- Administration functions (vshard related).
--
-- @module cartridge.lua-api.vshard

local rpc = require('cartridge.rpc')

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
