local remote_control = require('cartridge.remote-control')
local stateboard_client = require('cartridge.stateboard-client')

local t = require('luatest')
local g = t.group()

g.before_all(function()
    g.password = require('digest').urandom(6):hex()

    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    remote_control.accept({
        username = 'client',
        password = g.password,
    })

    rawset(_G, 'acquire_lock', function() return true end)
    rawset(_G, 'get_leaders', function() return {} end)
end)

g.after_all(function()
    remote_control.stop()
    remote_control.drop_connections()
    rawset(_G, 'acquire_lock', nil)
    rawset(_G, 'get_leaders', nil)
end)

local function create_client()
    return stateboard_client.new({
        uri = 'localhost:13301',
        password = g.password,
        call_timeout = 1,
    })
end

function g.test_session()
    -- check get_session always returns alive one
    local client = create_client()
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({'uuid', 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    -- check get_session creates new session if old one is dead
    remote_control.drop_connections()
    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Net.box call failed',
        err = 'Peer closed',
    })
    t.assert_is_not(client:get_session(), session)

    -- check that session looses lock if connection is interrupded
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)
end

function g.test_drop_session()
    local client = create_client()
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({'uuid', 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    client:drop_session()

    -- check dropping session makes it dead
    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'Net.box call failed',
        err = 'Connection closed',
    })

    -- check dropping session releases lock and make it dead
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    -- check drop session is idempotent
    client:drop_session()
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    t.assert_is_not(client:get_session(), session)
end
