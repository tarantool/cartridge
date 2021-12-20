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
    g.stateboard = helpers.Stateboard:new({
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
        c1:acquire_lock({uuid = kid, uri = 'localhost:9'}),
        true
    )
    t.assert_equals(
        c1:get_coordinator(),
        {uuid = kid, uri = 'localhost:9'}
    )

    t.assert_equals(
        c2:acquire_lock({uuid = uuid.str(), uri = 'localhost:11'}),
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
    c1:drop() -- it should be idempotent

    local kid = uuid.str()
    helpers.retrying({}, function()
        t.assert_equals({c2:get_coordinator()}, {nil})
    end)

    t.assert_equals(
        c2:acquire_lock({uuid = kid, uri = 'localhost:11'}),
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
        c:acquire_lock({uuid = kid, uri = 'localhost:9'}),
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
    t.assert_equals(err.class_name, 'NetboxCallError')
    if helpers.tarantool_version_ge('2.8.0') then
        t.assert_str_matches(err.err, '"localhost:13301": Duplicate key exists' ..
            ' in unique index "ordinal" in space "leader_audit".*')
    else
        t.assert_str_matches(err.err, "\"localhost:13301\": Duplicate key exists" ..
            " in unique index 'ordinal' in space 'leader_audit'.*")
    end
end

function g.test_longpolling()
    local c1 = create_client(g.stateboard):get_session()
    local kid = uuid.str()
    t.assert_equals(
        c1:acquire_lock({uuid = kid, uri = 'localhost:9'}),
        true
    )

    local client = create_client(g.stateboard)
    local function async_longpoll()
        local chan = fiber.channel(1)
        fiber.new(function()
            local ret, err = client:longpoll(0.2)
            chan:put({ret, err})
        end)
        return chan
    end

    -- Initial longpoll is instant even if there's no data yet
    local chan = async_longpoll()
    t.assert_equals(chan:get(0.1), {{}})

    -- Subsequent requests wait fairly
    local chan = async_longpoll()
    t.assert_equals(chan:get(0.05), nil) -- no data in channel yet
    t.assert_equals(chan:get(0.2), {{}}) -- data recieved

    -- New appointments arrive before the longpolling request
    -- Stateboard replies immediately
    c1:set_leaders({{'A', 'a1'}, {'B', 'b1'}})
    t.assert_equals(client:longpoll(0), {A = 'a1', B = 'b1'})

    -- The longpolling request arrives before new appointments
    -- Stateboard replies as soon as it gets new appointments
    local chan = async_longpoll()
    t.assert_equals(chan:get(0.05), nil)
    c1:set_leaders({{'A', 'a2'}})
    t.assert_equals(chan:get(0.1), {{A = 'a2'}})

    -- Stateboard client shouldn't miss appointments.
    -- See https://github.com/tarantool/cartridge/issues/1375
    c1:set_leaders({{'A', 'a3'}})
    g.stateboard.process:kill('STOP')
    local ok, err = client:longpoll(0)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = '"localhost:13301": Timeout exceeded',
    })

    g.stateboard.process:kill('CONT')
    c1:set_leaders({{'B', 'b3'}})
    t.assert_equals(client:longpoll(0), {A = 'a3', B = 'b3'})
    -- Before the fix it used to fail saying
    -- expected: {A = "a3", B = "b3"}
    -- actual: {B = "b3"}
end

g.after_test('test_longpolling', function()
    g.stateboard.process:kill('CONT')
end)

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

    local payload = {uuid = uuid.str(), uri = 'localhost:9'}

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

    local ok = session:acquire_lock({uuid = 'uuid', uri = 'uri'})
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
        err = '"localhost:13301": Peer closed',
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

    local ok = session:acquire_lock({uuid = 'uuid', uri = 'uri'})
    t.assert_equals(ok, true)
    t.assert_equals(session:is_alive(), true)
    t.assert_equals(session:is_locked(), true)
    t.assert_is(client:get_session(), session)

    client:drop_session()

    local ok, err = session:get_leaders()
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'NetboxCallError',
        err = '"localhost:13301": Connection closed',
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

function g.test_vclockkeeper()
    local client = create_client(g.stateboard)
    local session = client:get_session()

    local ok, err = session:get_vclockkeeper('A')
    t.assert_equals(ok, nil)
    t.assert_equals(err, nil)

    local ok, err = session:set_vclockkeeper('A', 'a1')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
    })

    local ok, err = session:set_vclockkeeper('A', 'a1', {[1] = 10})
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
        vclock = {[1] = 10},
    })

    local ok, err = session:set_vclockkeeper('A', 'a1')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a1',
        vclock = {[1] = 10},
    })

    local ok, err = session:set_vclockkeeper('A', 'a2')
    t.assert_equals({ok, err}, {true, nil})
    t.assert_equals(session:get_vclockkeeper('A'), {
        replicaset_uuid = 'A',
        instance_uuid = 'a2',
    })

    local function set_vclockkeeper_async(r, s, vclock)
        local chan = fiber.channel(1)
        fiber.new(function()
            chan:put({session:set_vclockkeeper(r, s, vclock)})
        end)
        return chan
    end

    g.stateboard.process:kill('STOP')
    local c1 = set_vclockkeeper_async('A', 'a3', {[1] = 101})
    local c2 = set_vclockkeeper_async('A', 'a3', {[1] = 102})
    fiber.sleep(0)
    g.stateboard.process:kill('CONT')

    t.assert_equals(c1:get(), {true, nil})
    local ret2, err2 = unpack(c2:get())
    t.assert_equals(ret2, nil)
    t.assert_equals(err2.class_name, 'SessionError')
    t.assert_str_matches(err2.err,
        'Ordinal comparison failed %(requested %d+, current %d+%)'
    )

    t.assert_equals(session:get_vclockkeeper('A').vclock, {[1] = 101})

    g.stateboard.process:kill('STOP')
    local c1 = set_vclockkeeper_async('B', 'b1')
    local c2 = set_vclockkeeper_async('B', 'b2')
    fiber.sleep(0)
    g.stateboard.process:kill('CONT')

    t.assert_equals(c1:get(), {true, nil})
    local ret2, err2 = unpack(c2:get())
    t.assert_equals(ret2, nil)
    t.assert_equals(err2.class_name, 'SessionError')
    t.assert_str_matches(err2.err,
        'Ordinal comparison failed %(requested nil, current %d+%)'
    )

    t.assert_equals(session:get_vclockkeeper('B'), {
        replicaset_uuid = 'B',
        instance_uuid = 'b1',
    })
end
