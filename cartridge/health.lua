local membership = require('membership')
local argparse = require('cartridge.argparse')

local function member_is_healthy(member)
    return (
        (member ~= nil)
        and (member.status == 'alive' or member.status == 'suspect')
        and (
            member.payload.state_prev == nil or -- for backward compatibility with old versions
            member.payload.state_prev == 'RolesConfigured' or
            member.payload.state_prev == 'ConfiguringRoles'
        )
        and (
            member.payload.state == 'ConfiguringRoles' or
            member.payload.state == 'RolesConfigured'
        )
    )
end

-- TODO
-- During the transfer of the metrics module to Tarantool, the same implementation of this function will occur
-- several times:
-- * https://github.com/tarantool/metrics/blob/master/cartridge/health.lua
-- * https://github.com/tarantool/cartridge/blob/master/cartridge/health.lua
-- * https://github.com/tarantool/cartridge/blob/master/cartridge/rpc.lua
local function is_healthy()
    local member = membership.myself()
    return box.info.status and box.info.status == 'running'
        and member_is_healthy(member)
end

local function default_is_healthy_handler(_)
    local parse = argparse.parse()
    local instance = parse.instance_name or parse.alias or 'instance'
    if is_healthy() then
        return {body = instance .. " is OK", status = 200}
    else
        return {body = instance .. " is dead", status = 500}
    end
end

return {
    member_is_healthy = member_is_healthy,
    is_healthy = is_healthy,
    default_is_healthy_handler = default_is_healthy_handler,
}
