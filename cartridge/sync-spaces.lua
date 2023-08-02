local log = require('log')
local vars = require('cartridge.vars').new('cartridge.sync-spaces')

vars:new('sync_spaces', {})

local function check_sync(old, new)
    if new == nil then
        vars.sync_spaces[old[3]] = nil
        return
    end
    local name = new[3]

    if new[6].is_sync then
        vars.sync_spaces[name] = true
    else
        vars.sync_spaces[name] = nil
    end
end

local function before_replace(old, new)
    check_sync(old, new)
    return new
end

local function on_schema_init()
    box.space._space:before_replace(before_replace)
end

--- List sync spaces.
--
-- @function spaces_list_str
-- @treturn string String of spaces with invalid params, delimeted by comma
local function spaces_list_str()
    local res = ''
    for name, _ in pairs(vars.sync_spaces) do
        res = res .. name .. ', '
    end
    return res:sub(1, -3)
end

--- Start check if spaces have invalid format in Tarantool 2.x.x.
-- In Tarantool 1.10 you can perform check by youself with function `run_check`.
--
-- @function start_check
local function start_check()
    if box.ctl.on_schema_init ~= nil then
        box.ctl.on_schema_init(on_schema_init)
    end
end


--- Remove set triggers and write message to log.
--
-- @function end_check
local function end_check()
    if box.ctl.on_schema_init ~= nil then
        box.space._space:before_replace(nil, before_replace)
        box.ctl.on_schema_init(nil, on_schema_init)
    end

    if next(vars.sync_spaces) then
        log.warn(
            "Having sync spaces may cause failover errors. " ..
            "Consider to change failover type to stateful and enable synchro_mode or use " ..
            "raft failover mode. Sync spaces: " ..
            spaces_list_str()
        )
    end
end

return {
    start_check = start_check,
    end_check = end_check,
    spaces_list_str = spaces_list_str,
}
