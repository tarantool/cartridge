local membership = require('membership')
local argparse = require('cartridge.argparse')

-- Original private member_is_healthy function:
-- https://github.com/tarantool/cartridge/blob/master/cartridge/rpc.lua
local function is_healthy(_)
    local member = membership.myself()
    local parse = argparse.parse()
    local instance = parse.instance_name or parse.alias or 'instance'
    if box.info.status and box.info.status == 'running'
        and member ~= nil
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
    then
        return {body = instance .. " is OK", status = 200}
    else
        return {body = instance .. " is dead", status = 500}
    end
end

return {is_healthy = is_healthy}
