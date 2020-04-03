local fio = require('fio')
local stateboard_client = require('cartridge.stateboard-client')

local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.datadir = fio.tempdir()
    g.password = require('digest').urandom(6):hex()
    g.lock_uuid = helpers.uuid('b', 'b', 1)
    g.lock_uri = 'localhost:13305'

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.kingdom = require('luatest.server'):new({
        command = fio.pathjoin(helpers.project_root, 'stateboard.lua'),
        workdir = fio.pathjoin(g.datadir),
        net_box_port = 13301,
        net_box_credentials = {
            user = 'client',
            password = g.password,
        },
        env = {
            TARANTOOL_PASSWORD = g.password,
            TARANTOOL_LOCK_DELAY = 40,
        },
    })
    g.kingdom:start()
    helpers.retrying({}, function()
        g.kingdom:connect_net_box()
    end)
end)

g.after_each(function()
    g.kingdom:stop()
    fio.rmtree(g.datadir)
end)

local function create_client(uri, password, call_timeout)
    return stateboard_client.new({
        uri = uri,
        password = password,
        call_timeout = call_timeout,
    })
end

-- creates new session on new client
local function create_session(client)
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)
    t.assert_is(client.session, session)
    return session
end

function g.test_refresh_session()
    local client = create_client('localhost:13301', g.password, 1)
    local session = create_session(client)

    local leaders, err = session:get_leaders()
    t.assert_equals(err, nil)
    t.assert_equals(leaders, {})
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    client:drop_session()
    t.assert_covers(session.connection, {error = 'Connection closed', state = 'closed'})

    local new_session = client:get_session()
    t.assert_is_not(new_session, session)
    new_session:drop()
    t.assert_covers(new_session.connection, {error = 'Connection closed', state = 'closed'})
    t.assert_is_not(client:get_session(), session)
end

function g.test_good_session()
    local client = create_client('localhost:13301', g.password, 1)
    local session = create_session(client)

    t.assert_covers(session, {
        lock_delay = nil,
        lock_acquired = false,
    })

    local leaders, err = session:get_leaders()
    t.assert_equals(err, nil)
    t.assert_equals(leaders, {})

    local delay, err = session:get_lock_delay()
    t.assert_equals(err, nil)
    t.assert_equals(delay, 40)
    t.assert_equals(session.lock_delay, delay)

    -----------------------------------------------------------------------------
    -- set_leaders and acquire_lock
    local replica_uuid = helpers.uuid('a')
    local leader_uuid = helpers.uuid('a', 'a', 1)
    local ok, err = session:set_leaders({{replica_uuid, leader_uuid}})
    t.assert_equals(err, 'You are not holding the lock')
    t.assert_equals(ok, nil)

    t.assert_equals(session:is_locked(), false)

    local ok, err = session:acquire_lock({g.lock_uuid, g.lock_uri})
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(session:is_locked(), true)

    local ok, err = session:set_leaders({{replica_uuid, leader_uuid}})
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)

    local leaders, err = session:get_leaders()
    t.assert_equals(err, nil)
    t.assert_equals(leaders, {[replica_uuid] = leader_uuid})

    t.assert_covers(session, {
        lock_delay = 40,
        lock_acquired = true
    })

    -----------------------------------------------------------------------------
    -- drop session
    -- explicitly close net_box connection
    session.connection:close()
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)
    t.assert_covers(session, {
        lock_delay = 40,
        lock_acquired = true
    })

    -- use session method to clear context
    session:drop()
    t.assert_covers(session, {
        lock_delay = 40,
        lock_acquired = false
    })
end

function g.test_broken_sessions()
    local client = create_client('localhost:13999', g.password, 1)
    local session = create_session(client)
    local leaders, err = session:get_leaders()
    t.assert_equals(leaders, nil)
    t.assert_equals(err.class_name, "Net.box call failed")

    local valid_errors = {
        ["Connection refused"] = true,
        ["Network is unreachable"] = true, -- inside docker
    }
    t.assert_equals(valid_errors[err.err], true)
    t.assert_equals(session:is_alive(), false)
    t.assert_is_not(client:get_session(), session)

    local client = create_client('localhost:13301', 'password', 1)
    local session = create_session(client)
    local leaders, err = session:get_leaders()
    t.assert_equals(leaders, nil)
    t.assert_covers(err, {
        class_name = "Net.box call failed",
        err = "Incorrect password supplied for user 'client'"
    })
    t.assert_equals(session:is_alive(), false)
    t.assert_is_not(client:get_session(), session)
end

function g.test_two_sesssions_acquire_lock()
    local client = create_client('localhost:13301', g.password, 1)
    local session = create_session(client)

    local ok, err = session:acquire_lock({g.lock_uuid, g.lock_uri})
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    local new_session = create_session(create_client('localhost:13301', g.password, 1))
    local ok, err = new_session:acquire_lock({g.lock_uuid, g.lock_uri})
    t.assert_equals(ok, false)
    t.assert_equals(err, nil)

    session:drop()
    t.assert_equals(session:is_locked(), false)
    t.assert_is_not(client:get_session(), session)

    t.helpers.retrying({}, function()
        local ok, err = new_session:acquire_lock({g.lock_uuid, g.lock_uri})
        t.assert_equals(ok, true)
        t.assert_equals(err, nil)
        t.assert_equals(new_session:is_locked(), true)
    end)
    new_session:drop()
end
