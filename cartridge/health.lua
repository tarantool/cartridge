local membership = require('membership')
local argparse = require('cartridge.argparse')

local function is_healthy_impl(member)
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

local function member_is_healthy(uri, instance_uuid)
    local member = membership.get_member(uri)
    return is_healthy_impl(member) and (member.payload.uuid == instance_uuid)
end

-- Based on
-- https://github.com/tarantool/metrics/blob/eb35baf54f687c559420bef020e7a8a1fee57132/cartridge/health.lua
local function is_healthy(_)
    local member = membership.myself()
    local parse = argparse.parse()
    local instance = parse.instance_name or parse.alias or 'instance'
    if box.info.status and box.info.status == 'running' and is_healthy_impl(member)
    then
        return {body = instance .. " is OK", status = 200}
    else
        return {body = instance .. " is dead", status = 500}
    end
end

return {
    is_healthy = is_healthy,
    member_is_healthy = member_is_healthy,
}
