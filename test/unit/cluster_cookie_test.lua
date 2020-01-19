#!/usr/bin/env tarantool

local fio = require('fio')

local t = require('luatest')
local g = t.group()

local cluster_cookie = require('cartridge.cluster-cookie')

function g.before_all()
    g.tempdir = fio.tempdir()
end

function g.after_all()
    fio.rmtree(g.tempdir)
end

function g.test_set_cookie()
    cluster_cookie.init(g.tempdir)

    cluster_cookie.set_cookie('abcdABCD1234_.~-')

    local _assert = t.assert_error_msg_equals
    local _set = cluster_cookie.set_cookie
    _assert([[Invalid symbol "\13" in cluster cookie]], _set, '\r')
    _assert([[Invalid symbol "\"" in cluster cookie]], _set, '"')
    _assert([[Invalid symbol "'" in cluster cookie]], _set, "'")
    _assert([[Invalid symbol "😎!" in cluster cookie]], _set, '😎!')
    _assert([[Invalid symbol "Ы" in cluster cookie]], _set, 'Ы')
    _assert([[Invalid symbol "@" in cluster cookie]], _set, '@')
    _assert([[Invalid symbol ":" in cluster cookie]], _set, ':a')
    _assert([[Invalid symbol "%%" in cluster cookie]], _set, '0%%1')
    _assert([[Invalid symbol "$" in cluster cookie]], _set, 'a$')
    _assert([[Could not set nil cluster cookie]], _set, nil)
    _assert([[Could not set cluster cookie with length more than 256]],
        _set, string.rep('x', 257)
    )
end
