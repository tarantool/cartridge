local t = require('luatest')
local format_listen = require('cartridge.lua-api.boxinfo').format_listen

local g = t.group()

function g.test_listen_uris()
    t.assert_equals(format_listen('fixture:sample@[::1]:3301?ssl_password=sample'), '[::1]:3301')
    t.assert_equals(format_listen('unix/:/tmp/cartridge.sock'), 'unix/:/tmp/cartridge.sock')
    t.assert_equals(format_listen('3301'), '3301')
end

function g.test_multiple_listen_uris()
    t.skip_if(require('uri').parse_many == nil, 'Multiple listen URIs are unsupported')
    local first = 'fixture:sample@127.0.0.1:3301'
    local second = '127.0.0.1:3302'
    t.assert_equals(format_listen(first .. ',' .. second), '127.0.0.1:3301,127.0.0.1:3302')
    t.assert_equals(format_listen({{uri = first}, {uri = second}}), '127.0.0.1:3301')
end
