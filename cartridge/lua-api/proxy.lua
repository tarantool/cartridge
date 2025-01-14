local mod_name = 'cartridge.lua-api.proxy'

local log = require('log')
local yaml = require('yaml')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local pool = require('cartridge.pool')
local vars = require('cartridge.vars').new(mod_name)
vars:new('destination')

local function get_destination()
    if vars.destination ~= nil then
        local member = membership.get_member(vars.destination)
        if member ~= nil and member.status == 'alive' then
            return vars.destination
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

    return vars.destination
end

local function can_call()
    return get_destination() ~= nil
end

local function call(function_name, ...)
    checks('string')

    local destination = get_destination()
    local conn = pool.connect(destination, {wait_connected = false, fetch_schema = false})

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
        log.warn('Proxy %s to %s: %s', function_name, destination, err)
        return nil, err
    end

    return yaml.decode(ret)
end

return {
    can_call = can_call,
    call = call,
}
