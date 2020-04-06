#!/usr/bin/env tarantool

local net_box = require('net.box')
local remote_control = require('cartridge.remote-control')
local stateboard_client = require('cartridge.stateboard-client')

local t = require('luatest')
local g = t.group()

local function mock_stateboard()
    remote_control.accept({
        username = 'client',
        password = g.cookie,
    })
    local conn = net_box.connect('localhost:13301', {password = g.cookie, user = 'client'})
    t.assert_not_equals(conn.state, 'error')

    conn:eval([[
        LOCK_DELAY = 10
        _G.lock = {
            session_id = 0,
            session_expiry = 0,
        }
        _G.leaders = {}

        _G.acquire_lock = function(uuid, uri)
            if box.session.id() ~= lock.session_id and box.session.exists(lock.session_id) then
                return false
            end

            lock.session_id = box.session.id()
            box.session.storage.lock_acquired = true

            return true
        end

        _G.set_leaders = function(leaders)
            if lock.session_id ~= box.session.id() then
                return nil, 'You are not holding the lock'
            end
            _G.leaders = leaders
            return true
        end

        _G.get_leaders = function()
            local ret = {}
            for _, v in pairs(leaders) do
                ret[v.replicaset_uuid] = v.instance_uuid
            end
            return ret
        end

        function _G.get_lock_delay()
            return LOCK_DELAY
        end
    ]])
end

g.before_all(function()
    g.cookie = require('digest').urandom(6):hex()

    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    mock_stateboard()
end)

g.after_all(function()
    remote_control.drop_connections()
    remote_control.stop()
end)

local function create_client(uri, password, call_timeout)
    return stateboard_client.new({
        uri = uri,
        password = password,
        call_timeout = call_timeout,
    })
end

function g.test_session()
    -- check get_session always returns alive one
    local client = create_client('localhost:13301', g.cookie, 1)
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
    local client = create_client('localhost:13301', g.cookie, 1)
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
