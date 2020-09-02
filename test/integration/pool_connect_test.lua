#!/usr/bin/env tarantool

local fio = require('fio')
local t = require('luatest')
local g = t.group()

local fiber = require('fiber')
local pool = require('cartridge.pool')
local cluster_cookie = require('cartridge.cluster-cookie')
local remote_control = require('cartridge.remote-control')

g.before_each(function()
    g.datadir = fio.tempdir()
    g.cookie = require('digest').urandom(6):hex()
    cluster_cookie.init(g.datadir)
    cluster_cookie.set_cookie(g.cookie)

    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end)

g.after_each(function()
    fio.rmtree(g.datadir)
    remote_control.drop_connections()
    remote_control.stop()
end)

function g.test_identity()
    local conn, err = pool.connect('localhost:13301', {wait_connected = false})
    t.assert_equals(err, nil)
    t.assert_covers(conn, {state = 'initial'})

    remote_control.accept({
        username = 'admin',
        password = g.cookie,
    })
    t.assert_is(pool.connect('localhost:13301'), conn)
    t.assert_covers(conn, {
        host = 'localhost',
        port = '13301',
        state = 'active',
        opts = {
            user = 'admin',
            wait_connected = false,
        },
    })

    conn:close()
end

function g.test_errors()
    local conn, err = pool.connect('localhost:13301', {wait_connected = 0})
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

function g.test_gc()
    -- The test may be flaky, see
    -- https://github.com/tarantool/tarantool/issues/5081

    remote_control.accept({
        username = 'admin',
        password = g.cookie,
    })

    local weak_table = setmetatable({}, {__mode = 'k'})

    local function connect()
        local conn, err = pool.connect('localhost:9', {
            wait_connected = false,
        })
        t.assert_equals(err, nil)
        weak_table[conn] = true
    end

    -- Test that it works
    pool.set_params({refkeeper_duration = 0})
    t.assert_equals(pool.get_params(), {refkeeper_duration = 0})
    connect()
    fiber.sleep(0.0)

    local csw1 = fiber.info()[fiber.id()].csw

    t.assert(next(weak_table))
    collectgarbage()
    t.assert_equals(next(weak_table), nil)

    local csw2 = fiber.info()[fiber.id()].csw
    assert(csw1 == csw2, 'Unexpected yield')

    -- Test timings
    pool.set_params({refkeeper_duration = 10})
    t.assert_equals(pool.get_params(), {refkeeper_duration = 10})
    connect()
    fiber.sleep(0.0)

    t.assert(next(weak_table))
    collectgarbage()
    t.assert(next(weak_table))

    pool.set_params({refkeeper_duration = 0.1})
    collectgarbage()
    t.assert(next(weak_table))
    fiber.sleep(0.2)
    t.assert(next(weak_table))
    collectgarbage()
    t.assert_equals(next(weak_table), nil)

    connect()
    t.assert(next(weak_table))
    fiber.sleep(0.2)
    t.assert(next(weak_table))
    collectgarbage()
    t.assert_equals(next(weak_table), nil)

    -- Test runtime reconfiguration
    pool.set_params({refkeeper_duration = math.huge})
    t.assert_equals(pool.get_params(), {refkeeper_duration = math.huge})
    connect()

    local csw1 = fiber.info()[fiber.id()].csw

    t.assert(next(weak_table))
    collectgarbage()
    t.assert(next(weak_table))
    pool.set_params({refkeeper_duration = 0})
    t.assert(next(weak_table))
    collectgarbage()
    t.assert_equals(next(weak_table), nil)

    local csw2 = fiber.info()[fiber.id()].csw
    assert(csw1 == csw2, 'Unexpected yield')
end
