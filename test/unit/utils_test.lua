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

function g.test_randomize_path()
    local digest = require('digest')
    local urandom_original = digest.urandom
    digest.urandom = function(n) return string.rep("\0", n) end

    t.assert_equals(
        utils.randomize_path('/some/file'),
        '/some/file.AAAAAAAAAAAA'
    )

    t.assert_equals(
        utils.randomize_path('/some/dir/'),
        '/some/dir.AAAAAAAAAAAA'
    )

    digest.urandom = urandom_original
end
