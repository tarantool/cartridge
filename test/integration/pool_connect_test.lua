#!/usr/bin/env tarantool

local fio = require('fio')
local fiber = require('fiber')
local t = require('luatest')
local g = t.group()

local pool = require('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')
local remote_control = require('cartridge.remote-control')

g.before_all(function()
    g.datadir = fio.tempdir()
    g.cookie = require('digest').urandom(6):hex()
    cluster_cookie.init(g.datadir)
    cluster_cookie.set_cookie(g.cookie)

    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end)

g.after_all(function()
    fio.rmtree(g.datadir)
    remote_control.drop_connections()
    remote_control.stop()
end)

function g.test_identity()
    local csw1 = fiber.info()[fiber.id()].csw
    local conn, err = pool.connect('localhost:13301', {wait_connected = false})
    local csw2 = fiber.info()[fiber.id()].csw

    t.assert_equals(csw1 + 1, csw2)
    t.assert_equals(err, nil)
    t.assert_covers(conn, {state = 'initial'})

    remote_control.accept({
        username = 'admin',
        password = g.cookie,
    })
    t.assert_is(pool.connect('localhost:13301'), conn)
    local csw3 = fiber.info()[fiber.id()].csw
    t.assert(csw3 > csw2)

    t.assert_covers(conn, {
        host = 'localhost',
        port = '13301',
        state = 'active',
        opts = {
            user = 'admin',
            wait_connected = false,
        },
    })

    local csw1 = fiber.info()[fiber.id()].csw

    local future = conn:call('box.info', nil, {is_async = true})
    local res, err = future:wait_result(0)

    local csw2 = fiber.info()[fiber.id()].csw
    t.assert_equals(csw1, csw2)
    t.assert_equals(res, nil)
    t.assert_equals(err, '"Timeout exceeded"')

    conn:close()
end

function g.test_errors()
    local csw1 = fiber.info()[fiber.id()].csw
    local conn, err = pool.connect('localhost:13301', {wait_connected = 0})
    local csw2 = fiber.info()[fiber.id()].csw
    t.assert_equals(csw1,  csw2)
    t.assert_equals(conn, nil)
    t.assert_covers(err, {
        class_name = 'NetboxConnectError',
        err = '"localhost:13301": Connection not established (yet)'
    })

    local conn, err = pool.connect('tarantool.io')
    t.assert_equals(conn, nil)
    t.assert_covers(err, {
        class_name = 'FormatURIError',
        err = 'Invalid URI "tarantool.io" (missing port)'
    })
end
