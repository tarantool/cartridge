local yaml = require('yaml')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local pool = require('cartridge.pool')
local confapplier = require('cartridge.confapplier')

local vars = require('cartridge.vars').new('cartridge.lua-api.proxy')

vars:new('destination')

local function call(function_name, ...)
    checks('string')

    if confapplier.get_state() ~= 'Unconfigured' then
        return nil
    end

    if vars.destination ~= nil then
        local member = membership.get_member(vars.destination)
        if member ~= nil and member.status == 'alive' then
            goto call
        else
            vars.destination = nil
        end
    end

    for _, member in membership.pairs() do
        if member.status ~= 'alive'
        or member.payload.uuid == nil
        then
            goto continue
        end

        -- For the sake of destination determinism choose
        -- the member with the lowest uri (lexicographically)
        if vars.destination == nil
        or member.uri < vars.destination
        then
            vars.destination = member.uri
        end

        ::continue::
    end

    if vars.destination == nil then
        return nil
    end

::call::
    local conn = pool.connect(vars.destination, {wait_connected = false})

    -- Both get_topology and edit_topology API return recursive lua
    -- tables which can't be passed over netbox as is. So we transfer
    -- them as yaml.
    local ret, err = errors.netbox_eval(conn, [[
        local ret, err = require('cartridge.funcall').call(...)
        if ret == nil then return nil, err end
        return require('yaml').encode(ret)
    ]], {function_name, ...})

    if ret == nil then
        vars.destination = nil
        return nil, err
    end

    return yaml.decode(ret)
end

return {
    call = call,
}
