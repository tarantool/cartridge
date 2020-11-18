local t = require('luatest')
local g = t.group()

local utils = require('cartridge.utils')

function g.test_upvalues()
    local f
    do
        local t1, t2 = 1, 2
        function f() return t1, t2 end
    end

    utils.assert_upvalues(f, {'t1', 't2'})
    t.assert_error_msg_equals(
        'Unexpected upvalues, [t3] expected, got [t1, t2]',
        utils.assert_upvalues, f, {'t3'}
    )
end
