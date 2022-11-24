local log = require('log')
local fiber = require('fiber')
local vars = require('cartridge.vars').new('cartridge.invalid-format')

--- Set of illegal params.
--
-- @table illegal_types
local illegal_types = {
    [''] = true,
    ['n'] = true,
    ['nu'] = true,
    ['s'] = true,
    ['st'] = true,
}

vars:new('invalid_format_spaces', {})

local function check_format(tuple)
    local name = tuple[3]
    local format = tuple[7]

    for _, field_def in ipairs(format) do
        if illegal_types[field_def.type] or illegal_types[field_def[2]] then
            vars.invalid_format_spaces[name] = true
        end
    end
end

local function before_replace(_, tuple)
    if tuple == nil then return tuple end
    check_format(tuple)
    return tuple
end

local function on_schema_init()
    box.space._space:before_replace(before_replace)
end

--- Check if spaces have invalid format.
--
-- @function start_check
-- @treturn string String of spaces with invalid params, delimeted by comma
local function spaces_list_str()
    local res = ''
    for name, _ in pairs(vars.invalid_format_spaces) do
        res = res .. name .. ', '
    end
    return res:sub(1, -3)
end

--- Check if spaces have invalid format.
--
-- @function run_check
-- @treturn {string=true,...} Set of spaces with invalid format
local function run_check()
    vars.invalid_format_spaces = {}
    local n = 0
    for _, tuple in box.space._space:pairs(512, {iterator = 'GE'}) do
        check_format(tuple)
        n = n + 1
        if n % 500 == 0 then
            fiber.yield()
        end
    end
    return vars.invalid_format_spaces
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

    if next(vars.invalid_format_spaces) then
        log.warn(
            "You have spaces with invalid format: " ..
            spaces_list_str() ..
            ". Fix it before use Tarantool 2.10.4 - it's deprecated and " ..
            "will be prohibited in next releases. " ..
            "For more details, see " ..
            "https://github.com/tarantool/tarantool/"..
            "wiki/Fix-illegal-field-type-in-a-space-format-when-upgrading-to-2.10.4"
        )
    end
end

return {
    start_check = start_check,
    end_check = end_check,
    spaces_list_str = spaces_list_str,
    run_check = run_check,
}
