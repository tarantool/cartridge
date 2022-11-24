local log = require('log')

local illegal_types = {
    [''] = true,
    ['n'] = true,
    ['nu'] = true,
    ['s'] = true,
    ['st'] = true,
}

rawset(_G, '__cartridge_invalid_format_spaces', {})

-- _space trigger.
local function before_replace(_, tuple)
    if tuple == nil then return tuple end

    local name = tuple[3]
    local format = tuple[7]

    for _, field_def in ipairs(format) do
        if illegal_types[field_def.type] then
            _G.__cartridge_invalid_format_spaces[name] = true
        end
    end

    return tuple
end

-- on_schema_init trigger to set before_replace().
local function on_schema_init()
    box.space._space:before_replace(before_replace)
end

local function spaces_name_to_str()
    local res = ''
    for name, _ in pairs(_G.__cartridge_invalid_format_spaces) do
        res = res .. name .. ', '
    end
    return res:sub(1, -3)
end

return {
    start_check = function()
        box.ctl.on_schema_init(on_schema_init)
    end,
    end_check = function()
        box.space._space:before_replace(nil, before_replace)
        box.ctl.on_schema_init(nil, on_schema_init)

        if next(_G.__cartridge_invalid_format_spaces) then
            log.warn(
                "You have spaces with invalid format: " ..
                spaces_name_to_str() ..
                ". Fix it before use Tarantool 2.10.4 - it's deprecated and " ..
                "will be prohibited in next releases. " ..
                "For more details, see " ..
                "https://github.com/tarantool/tarantool/"..
                "wiki/Fix-illegal-field-type-in-a-space-format-when-upgrading-to-2.10.4"
            )
        end
    end
}
