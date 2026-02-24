local fiber = require('fiber')
local vars = require('cartridge.vars').new('cartridge.sync-spaces')
vars:new('sync_spaces', {})

local yield_every = 100

local function update_sync_spaces_vars()
    -- for test purposes
    if type(box.cfg) == 'function' then
        return
    end

    local count = 0
    for space_name, space_info in pairs(box.space) do
        if type(space_name) == 'string' then
            vars.sync_spaces[space_name] = space_info.is_sync or nil
        end

        count = count + 1
        if count % yield_every == 0 then
            fiber.yield()
        end
    end
end

--- List sync spaces.
--
-- @function spaces_list_str
-- @treturn string String of sync space names, delimited by comma
local function spaces_list_str()
    update_sync_spaces_vars()

    local sync_spaces_list = {}
    for name, is_sync in pairs(vars.sync_spaces) do
        if is_sync then
            table.insert(sync_spaces_list, name)
        end
    end
    return table.concat(sync_spaces_list, ', ')
end

return {
    spaces_list_str = spaces_list_str,
}

