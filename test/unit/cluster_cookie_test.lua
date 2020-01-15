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

	cluster_cookie.set_cookie('abcd')
	cluster_cookie.set_cookie('ABCD')
	cluster_cookie.set_cookie('1234')
	cluster_cookie.set_cookie('-_.~')
	cluster_cookie.set_cookie('abcdABCD1234-_.~')

	local err_msg = 'Invalid symbol "%s" in cluster cookie'
	t.assert_error_msg_contains(string.format(err_msg, 'Ы'), cluster_cookie.set_cookie, 'Ы')
	t.assert_error_msg_contains(string.format(err_msg, '@'), cluster_cookie.set_cookie, '@')
	t.assert_error_msg_contains(string.format(err_msg, ':'), cluster_cookie.set_cookie, ':a')
	t.assert_error_msg_contains(string.format(err_msg, '$'), cluster_cookie.set_cookie, 'a$')
end
