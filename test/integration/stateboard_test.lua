local fio = require('fio')
local uuid = require('uuid')
local fiber = require('fiber')
local stateboard_client = require('cartridge.stateboard-client')
local t = require('luatest')
local g = t.group()

local helpers = require('test.helper')

g.before_each(function()
    g.datadir = fio.tempdir()
    local password = require('digest').urandom(6):hex()

    fio.mktree(fio.pathjoin(g.datadir, 'stateboard'))
    g.stateboard = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.pathjoin(g.datadir),
        net_box_port = 13301,
        net_box_credentials = {
            user = 'client',
            password = password,
        },
        env = {
            TARANTOOL_PASSWORD = password,
            TARANTOOL_LOCK_DELAY = 40,
        },
    })
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)
end)

g.after_each(function()
    g.stateboard:stop()
    fio.rmtree(g.datadir)
end)

local function create_client(srv)
    return stateboard_client.new({
        uri = 'localhost:' .. srv.net_box_port,
        password = srv.net_box_credentials.password,
        call_timeout = 1,
    })
end

function g.test_locks()
    local session1 = create_client(g.stateboard):get_session()
    local session2 = create_client(g.stateboard):get_session()
    local kid = uuid.str()

    t.assert_equals(
        session1:acquire_lock({kid, 'localhost:9'}),
        true
    )
    t.assert_equals(
        session1:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert_equals(
        session2:acquire_lock({uuid.str(), 'localhost:11'}),
        false
    )

    local ok, err = session2:set_leaders({{'A', 'a1'}})
    t.assert_equals(ok, nil)
    t.assert_equals(err, 'You are not holding the lock')

    t.assert_equals(
        session2:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    session1:drop()

    local kid = uuid.str()
    helpers.retrying({}, function()
        t.assert_equals(session2:get_coordinator(), nil)
    end)

    t.assert_equals(
        session2:acquire_lock({kid, 'localhost:11'}),
        true
    )
    t.assert_equals(
        session2:get_coordinator(),
        {uuid = kid, uri = 'localhost:11'}
    )
end

function g.test_appointments()
    local session = create_client(g.stateboard):get_session()
    local kid = uuid.str()
    t.assert_equals(
        session:acquire_lock({kid, 'localhost:9'}), true
    )

    t.assert_equals(
        session:set_leaders({{'A', 'a1'}, {'B', 'b1'}}), true
    )

    t.assert_equals(
        session:get_leaders(), {A = 'a1', B = 'b1'}
    )

    local ok, err = session:set_leaders({{'A', 'a2'}, {'A', 'a3'}})
    t.assert_equals(ok, nil)
    t.assert_equals(err.err,
        "Duplicate key exists in unique index 'ordinal'" ..
        " in space 'leader_audit'"
    )
end

function g.test_longpolling()
    local client1 = create_client(g.stateboard)
    local session1 = client1:get_session()
    local kid = uuid.str()
    t.assert_equals(
        session1:acquire_lock({kid, 'localhost:9'}),
        true
    )
    session1:set_leaders({{'A', 'a1'}, {'B', 'b1'}})

    local client2 = create_client(g.stateboard)
    t.assert_equals(client2:longpoll(0), {A = 'a1', B = 'b1'})

    local function async_longpoll()
        local chan = fiber.channel(1)
        fiber.new(function()
            local ret, err = client2:longpoll(0.2)
            chan:put({ret, err})
        end)
        return chan
    end

    local chan = async_longpoll()
    session1:set_leaders({{'A', 'a2'}})
    t.assert_equals(chan:get(0.1), {{A = 'a2'}, nil})

    local chan = async_longpoll()
    -- there is no data in channel
    t.assert_equals(chan:get(0.1), nil)

    -- data recieved
    t.assert_equals(chan:get(0.2), {{}, nil})
end

function g.test_passwd()
    local new_password = require('digest').urandom(6):hex()

    g.stateboard:stop()
    g.stateboard.env.TARANTOOL_PASSWORD = new_password
    g.stateboard.net_box_credentials.password = new_password
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)

    t.assert_equals(create_client(g.stateboard):get_session():get_lock_delay(), 40)
end

function g.test_outage()
    -- Test case:
    -- 1. Coordinator C1 acquires a lock and freezes;
    -- 2. Lock delay expires and stateboard allows C2 to acquire it again;
    -- 3. C2 writes some decisions and releases a lock;
    -- 4. C1 comes back;
    -- Goal: C1 must be informed on his outage

    g.stateboard:stop()
    g.stateboard.env.TARANTOOL_LOCK_DELAY = '0'
    g.stateboard:start()
    helpers.retrying({}, function()
        g.stateboard:connect_net_box()
    end)

    local payload = {uuid.str(), 'localhost:9'}

    local session1 = create_client(g.stateboard):get_session()
    t.assert_equals(
        session1:acquire_lock(payload), true
    )
    t.assert_equals(
        -- C1 can renew expired lock if it wasn't stolen yet
        session1:acquire_lock(payload), true
    )

    local session2 = create_client(g.stateboard):get_session()
    t.assert_equals(
        session2:acquire_lock(payload), true
    )
    session2:drop()

    -- C1 can't renew lock after it was stolen by C2
    local ok, err = session1:acquire_lock(payload)
    t.assert_equals(ok, nil)
    t.assert_equals(err, 'The lock was stolen')

    local ok, err = session1:set_leaders({})
    t.assert_equals(ok, nil)
    t.assert_equals(err, 'You are not holding the lock')
end
