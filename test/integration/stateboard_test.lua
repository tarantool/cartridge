local fio = require('fio')
local uuid = require('uuid')
local fiber = require('fiber')
local socket = require('socket')
local utils = require('cartridge.utils')
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
            TARANTOOL_CONSOLE_SOCK = fio.pathjoin(g.datadir, 'console.sock'),
            NOTIFY_SOCKET = fio.pathjoin(g.datadir, 'notify.sock'),
            TARANTOOL_PID_FILE = 'stateboard.pid',
            TARANTOOL_CUSTOM_PROC_TITLE = 'stateboard-proc-title',
        },
    })

    local notify_socket = socket('AF_UNIX', 'SOCK_DGRAM', 0)
    t.assert(notify_socket, 'Can not create socket')
    t.assert(
        notify_socket:bind('unix/', g.stateboard.env.NOTIFY_SOCKET),
        notify_socket:error()
    )

    g.stateboard:start()

    t.helpers.retrying({}, function()
        t.assert(notify_socket:readable(1), "Socket isn't readable")
        t.assert_str_matches(notify_socket:recv(), 'READY=1')
    end)

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
    local c1 = create_client(g.stateboard):get_session()
    local c2 = create_client(g.stateboard):get_session()
    local kid = uuid.str()

    t.assert_equals(
        c1:acquire_lock({kid, 'localhost:9'}),
        true
    )
    t.assert_equals(
        c1:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert_equals(
        c2:acquire_lock({uuid.str(), 'localhost:11'}),
        false
    )

    local ok, err = c2:set_leaders({{'A', 'a1'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'You are not holding the lock'
    })

    t.assert_equals(
        c2:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    c1:drop()

    local kid = uuid.str()
    helpers.retrying({}, function()
        t.assert_equals({c2:get_coordinator()}, {nil})
    end)

    t.assert_equals(
        c2:acquire_lock({kid, 'localhost:11'}),
        true
    )
    t.assert_equals(
        c2:get_coordinator(),
        {uuid = kid, uri = 'localhost:11'}
    )
end

function g.test_appointments()
    local c = create_client(g.stateboard):get_session()
    local kid = uuid.str()
    t.assert_equals(
        c:acquire_lock({kid, 'localhost:9'}),
        true
    )

    t.assert_equals(
        c:set_leaders({{'A', 'a1'}, {'B', 'b1'}}),
        true
    )

    t.assert_equals(
        c:get_leaders(),
        {A = 'a1', B = 'b1'}
    )

    local ok, err = c:set_leaders({{'A', 'a2'}, {'A', 'a3'}})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = "Duplicate key exists in unique index 'ordinal'" ..
        " in space 'leader_audit'"
    })
end

function g.test_longpolling()
    local c1 = create_client(g.stateboard):get_session()
    local kid = uuid.str()
    t.assert_equals(
        c1:acquire_lock({kid, 'localhost:9'}),
        true
    )
    c1:set_leaders({{'A', 'a1'}, {'B', 'b1'}})

    local client = create_client(g.stateboard)
    local function async_longpoll()
        local chan = fiber.channel(1)
        fiber.new(function()
            local ret, err = client:longpoll(0.2)
            chan:put({ret, err})
        end)
        return chan
    end

    t.assert_equals(client:longpoll(0), {A = 'a1', B = 'b1'})

    local chan = async_longpoll()
    c1:set_leaders({{'A', 'a2'}})
    t.assert_equals(chan:get(0.1), {{A = 'a2'}})

    local chan = async_longpoll()
    -- there is no data in channel
    t.assert_equals(chan:get(0.1), nil)

    -- data recieved
    t.assert_equals(chan:get(0.2), {{}})
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

    local c1 = create_client(g.stateboard):get_session()
    t.assert_equals(
        {c1:acquire_lock(payload)},
        {true}
    )
    t.assert_equals(
        -- C1 can renew expired lock if it wasn't stolen yet
        {c1:acquire_lock(payload)},
        {true}
    )

    local c2 = create_client(g.stateboard):get_session()
    t.assert_equals(
        {c2:acquire_lock(payload)},
        {true}
    )
    c2:drop()

    -- C1 can't renew lock after it was stolen by C2
    local ok, err = c1:acquire_lock(payload)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'The lock was stolen'
    })

    local ok, err = c1:set_leaders({})
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'SessionError',
        err = 'You are not holding the lock'
    })
end

function g.test_client_session()
    -- get_session always returns alive one
    local client = create_client(g.stateboard)
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({'uuid', 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    -- get_session creates new session if old one is dead
    g.stateboard:stop()
    t.helpers.retrying({}, function()
        t.assert_covers(session.connection, {
            state = 'error',
            error = 'Peer closed'
        })
    end)

    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = 'Peer closed',
    })
    t.assert_is_not(client:get_session(), session)

    -- session looses lock if connection is interrupded
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)
end

function g.test_client_drop_session()
    local client = create_client(g.stateboard)
    local session = client:get_session()
    t.assert_equals(session:is_alive(), true)
    t.assert_is(client:get_session(), session)

    local ok = session:acquire_lock({'uuid', 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    client:drop_session()

    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = 'Connection closed',
    })

    -- dropping session releases lock and make it dead
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    -- dropping session is idempotent
    client:drop_session()
    t.assert_equals(session:is_alive(), false)
    t.assert_equals(session:is_locked(), false)

    t.assert_is_not(client:get_session(), session)
end

function g.test_stateboard_console()
    local s = socket.tcp_connect(
        'unix/', g.stateboard.env.TARANTOOL_CONSOLE_SOCK
    )
    t.assert(s)
    local greeting = s:read('\n')
    t.assert(greeting)
    t.assert_str_matches(greeting:strip(), 'Tarantool.*%(Lua console%)')
end

function g.test_box_options()
    local pid_file = fio.pathjoin(
        g.stateboard.workdir,
        g.stateboard.env.TARANTOOL_PID_FILE
    )

    local pid, err = utils.file_read(pid_file)
    t.assert_equals(err, nil)
    t.assert_equals(pid, tostring(g.stateboard.process.pid))

    local ps = io.popen('ps -o args= -p ' .. pid)
    t.assert_str_matches(ps:read('*all'):strip(),
        'tarantool .+ <running>: stateboard%-proc%-title'
    )
end
