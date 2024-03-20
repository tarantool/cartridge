#!/usr/bin/env tarantool

local fio = require('fio')
local t = require('luatest')
local g = t.group()

local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local cluster_cookie = require('cartridge.cluster-cookie')
local remote_control = require('cartridge.remote-control')

local helpers = require('test.helper')

g.before_all(function()
    g.datadir = fio.tempdir()
    g.cookie = helpers.random_cookie()
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
    local csw1 = utils.fiber_csw()
    local conn, err = pool.connect('localhost:13301', {wait_connected = false})
    local csw2 = utils.fiber_csw()

    -- netbox.connect implicitly calls fiber.create(...)
    -- so there would be one context switch
    -- changed in 2.11: netbox.connect doesn't yield
    if not helpers.tarantool_version_ge('2.11.2') then
        t.assert_equals(csw1 + 1, csw2)
    end
    t.assert_equals(err, nil)
    t.assert_covers(conn, {state = 'initial'})

    remote_control.accept({
        username = 'admin',
        password = g.cookie,
    })
    t.assert_is(pool.connect('localhost:13301'), conn)
    local csw3 = utils.fiber_csw()
    t.assert(csw3 > csw2)

    t.assert_covers(conn, {
        host = 'localhost',
        port = '13301',
        state = 'active',
        opts = {
            user = 'admin',
            wait_connected = false,
            fetch_schema = false,
        },
    })

    conn:close()
end

function g.test_fetch_schema()
    local conn, err = pool.connect('localhost:13301', {wait_connected = false, fetch_schema = true})
    t.assert_not(err)

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
            fetch_schema = true,
        },
    })

    conn:close()
end

function g.test_errors()
    local csw1 = utils.fiber_csw()
    local conn, err = pool.connect('localhost:13301', {wait_connected = 0})
    local csw2 = utils.fiber_csw()

    -- netbox.connect implicitly calls fiber.create (+1 context switch)
    -- and calls cond:wait(0) (wait for connection active state) (+1 context switch)
    -- changed in 2.11: netbox.connect doesn't yield
    if not helpers.tarantool_version_ge('2.11.2') then
        t.assert_equals(csw1 + 2,  csw2)
    end
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

function g.test_async_call_not_yeilds()
    local conn = pool.connect('localhost:13301')

    local csw1 = utils.fiber_csw()
    local future = conn:call('math.abs', nil, {is_async = true})
    local res, err = future:wait_result(0)

    -- creating future and wait_result(0) won't yeild
    t.assert_equals(csw1, utils.fiber_csw())

    t.assert_equals(res, nil)
    t.assert(helpers.is_timeout_error(err))
end

function g.test_async_call_wait_result_err()
    local conn = pool.connect('localhost:13301')
    local future = conn:call('math.abs', {'bad'}, {is_async = true})

    -- check wait_results throws an error
    t.assert_error_msg_contains(
        'Usage: future:wait_result(timeout)',
        future.wait_result, future, -1
    )

    t.assert_error_msg_contains(
        'Usage: future:wait_result(timeout)',
        future.wait_result, future, 'Not a number'
    )

    -- check wait results return nil, err
    conn:close()
    local ok, err = future:wait_result()
    t.assert_equals(ok, nil)
    t.assert_equals(tostring(err), 'Connection closed')
end

function g.test_async_call_remote()
    local conn = pool.connect('localhost:13301')

    -- wait_result returns nil, err if remote function throws an error
    local future = conn:call('math.abs', {'bad'}, {is_async = true})
    local ok, err = future:wait_result()
    t.assert_equals(ok, nil)
    t.assert_equals(tostring(err),
        "bad argument #1 to '?' (number expected, got string)"
    )

    local future = conn:call('math.abs', {-1}, {is_async = true})
    t.assert_equals(future:wait_result(), {1})

    local future = conn:call('pcall', {'smth'}, {is_async = true})
    t.assert_equals({future:wait_result()}, {{false, 'attempt to call a string value'}})
end

function g.test_schema_fetch()
    t.skip_if(not helpers.tarantool_version_ge('2.10.0'))
    local conn = pool.connect('localhost:13301')
    t.assert_equals(conn.space, nil)
end
