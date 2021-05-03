local t = require('luatest')
local g = t.group()

local log = require('log')
local fiber = require('fiber')
local digest = require('digest')
local socket = require('socket')
local pickle = require('pickle')
local netbox = require('net.box')
local msgpack = require('msgpack')
local tarantool = require('tarantool')
local remote_control = require('cartridge.remote-control')
local helpers = require('test.helper')
local errno = require('errno')

local username = 'superuser'
local password = '3.141592'

local secret = digest.urandom(32):hex()
local function get_local_secret()
    return secret
end

_G.get_local_secret = get_local_secret
_G.indexed = setmetatable({}, {__index = {get_local_secret = get_local_secret}})
_G.callable = setmetatable({}, {__call = get_local_secret})
_G.uncallable = setmetatable({}, {__call = _G.callable})
_G.multireturn = function()
    return nil, 'Artificial Error', 3
end
_G.varargs = function(...)
    return ...
end
_G.eval = function(code)
    return loadstring(code)()
end
_G.object = {}
function _G.object:method()
    assert(self == _G.object, "Use object:method instead")
end

g.before_all(function()
    helpers.box_cfg()
    box.schema.user.create(
        username,
        { if_not_exists = true }
    )
    box.schema.user.grant(
        username,
        'execute',
        'universe',
        nil,
        { if_not_exists = true }
    )
    box.schema.user.passwd(username, password)
end)

local function rc_start(port)
    local ok, err = remote_control.bind('127.0.0.1', port)

    t.assert_equals(err, nil)
    t.assert_equals(ok, true)

    remote_control.accept({
        username = username,
        password = password,
    })
end

g.after_each(function()
    box.cfg({listen = box.NULL})
    remote_control.stop()
    collectgarbage() -- cleanup sockets, created with netbox.connect
end)

-------------------------------------------------------------------------------

local function assertStrOneOf(str, possible_values)
    for _, v in pairs(possible_values) do
        if str == v then
            return
        end
    end

    error(
        string.format(
            "expected one of: \n%s\nactual: %s",
            table.concat(possible_values, "\n"), str
        ), 2
    )
end

function g.test_start()
    rc_start(13301)
    box.cfg({listen = box.NULL})
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_not(ok)
    t.assert_covers(err, {
        class_name = "RemoteControlError",
        err = "Already running"
    })

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13301'})
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_not(ok)
    t.assert_covers(err, {
        class_name = "RemoteControlError",
        err = "Can't start server on 127.0.0.1:13301: " .. errno.strerror(errno.EADDRINUSE)
    })

    remote_control.stop()
    box.cfg({listen = box.NULL})

    local ok, err = remote_control.bind('0.0.0.0', -1)
    t.assert_not(ok)
    t.assert_equals(err.class_name, "RemoteControlError")
    -- MacOS and Linux returns different errno
    assertStrOneOf(err.err, {
        "Can't start server on 0.0.0.0:-1: " .. errno.strerror(errno.EIO),
        "Can't start server on 0.0.0.0:-1: " .. errno.strerror(errno.EAFNOSUPPORT),
    })

    local ok, err = remote_control.bind('255.255.255.255', 13301)
    t.assert_not(ok)
    t.assert_covers(err, {
        class_name = "RemoteControlError",
        err = "Can't start server on 255.255.255.255:13301: " .. errno.strerror(errno.EINVAL)
    })

    local ok, err = remote_control.bind('google.com', 13301)
    t.assert_not(ok)
    t.assert_covers(err, {
        class_name = "RemoteControlError",
        err = "Can't start server on google.com:13301: " .. errno.strerror(errno.EADDRNOTAVAIL)
    })

    local ok, err = remote_control.bind('8.8.8.8', 13301)
    t.assert_not(ok)
    t.assert_covers(err, {
        class_name = "RemoteControlError",
        err = "Can't start server on 8.8.8.8:13301: " .. errno.strerror(errno.EADDRNOTAVAIL)
    })

    local ok, err = remote_control.bind('localhost', 13301)
    t.assert_not(err)
    t.assert_equals(ok, true)
    remote_control.stop()
end

function g.test_peer_uuid()
    rc_start(13301)
    local conn = assert(netbox.connect('localhost:13301'))
    t.assert_equals(conn.peer_uuid, "00000000-0000-0000-0000-000000000000")
end

function g.test_fiber_name()
    local function check_conn(conn, fiber_name)
        t.assert_not(conn.error)

        t.assert_str_matches(
            conn:eval('return package.loaded.fiber.name()'),
            fiber_name
        )

        t.assert_str_matches(
            conn:call('package.loaded.fiber.name'),
            fiber_name
        )

        t.assert_not(conn.error)
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    check_conn(conn_rc, 'remote_control/.+:.+')
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:3.141592@localhost:13302'))
    check_conn(conn_box, 'main') -- Box doesn't care about netbox fiber names
    conn_box:close()
end

function g.test_drop_connections()
    rc_start(13301)
    local conn_1 = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    local conn_2 = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    t.assert_equals({conn_1.state, conn_1.error}, {"active"})
    t.assert_equals({conn_2.state, conn_2.error}, {"active"})
    rawset(_G, 'conn_1', conn_1)
    rawset(_G, 'conn_2', conn_2)

    -- Check that the presence of a closed connection doesn't cause errors
    netbox.connect('superuser:3.141592@localhost:13301'):close()

    -- Check that remote-control server is able to handle requests asynchronously
    local ch = fiber.channel(0)
    rawset(_G, 'longrunning', function() ch:put(secret) end)
    local future = conn_2:call('longrunning', {1}, {is_async=true})

    local result = helpers.run_remotely({net_box = conn_1}, function()
        local t = require('luatest')
        local remote_control = require('cartridge.remote-control')

        t.assert_equals({_G.conn_1.state, _G.conn_1.error}, {"active"})
        t.assert(_G.conn_1:ping({timeout = 0.1}))
        t.assert(_G.conn_2:ping({timeout = 0.1}))

        remote_control.stop()
        package.loaded.fiber.yield()
        remote_control.drop_connections()

        --
        t.assert_equals(_G.conn_2:ping(), false)
        t.assert_covers(_G.conn_2, {
            state = "error",
            error = "Peer closed",
        })

        -- Our own connection should remain operable
        -- until the last response is sent
        t.assert(_G.conn_1:ping())
        t.assert(_G.conn_1:eval('return true'))
        return _G.conn_1:call('get_local_secret')
    end)

    -- Both connections are closed as soon as eval returns
    t.assert_equals({conn_1.state, conn_1.error}, {"error", "Peer closed"})
    t.assert_equals({conn_2.state, conn_2.error}, {"error", "Peer closed"})

    -- conn_1 was able to get the response
    t.assert_equals(result, secret)

    -- conn_2 was dropped
    t.assert_equals(future:is_ready(), true)
    local ok, err = future:result()
    t.assert_not(ok)
    t.assert_equals(type(err), 'cdata')
    t.assert_equals(err.message, 'Peer closed')
    -- but its handler is still alive
    t.assert_equals(ch:get(0), secret)

    -- Cleanup globals
    rawset(_G, 'conn_1', nil)
    rawset(_G, 'conn_2', nil)
    rawset(_G, 'longrunning', nil)
end

function g.test_late_accept()
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
    local url = 'superuser:3.141592@localhost:13301'

    local f = fiber.new(netbox.connect, url)
    f:name('netbox_connect')
    f:set_joinable(true)

    local conn_1 = netbox.connect(url, {wait_connected = false})
    t.assert_equals({conn_1.state, conn_1.error}, {"initial", nil})

    local conn_2 = netbox.connect(url, {connect_timeout = 0.2})
    t.assert_equals({conn_2.state, conn_2.error}, {"error", errno.strerror(errno.ETIMEDOUT)})

    remote_control.drop_connections()

    local ok, conn_3 = f:join()
    t.assert_equals(ok, true)
    t.assert_equals({conn_1.state, conn_1.error}, {"error", "Invalid greeting"})
    t.assert_equals({conn_3.state, conn_3.error}, {"error", "Invalid greeting"})

    --------------------------------------------------------------------
    local conn_4 = netbox.connect(url, {wait_connected = false})
    t.assert_equals({conn_4.state, conn_4.error}, {"initial", nil})

    remote_control.accept({username = username, password = password})
    t.assert_equals(conn_4:wait_connected(1), true)
    t.assert_equals({conn_4.state, conn_4.error}, {"active", nil})
end

function g.test_auth()
    rc_start(13301)
    local conn = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    t.assert_not(conn.error)
    t.assert_equals(conn.state, "active")
end

function g.test_ping()
    rc_start(13301)
    local conn = assert(netbox.connect('localhost:13301'))
    t.assert_equals(conn:ping(), true)
end

function g.test_bytestream()
    -- Check ability to handle fragmented stream properly

    local function check_conn(conn)
        assert(conn, errno.strerror())
        conn:read(128) -- greeting

        local header = msgpack.encode({
            [0x00] = 0x40, -- code = ping
            [0x01] = 1337, -- sync = 1337
        })
        local message = '\xCE' .. pickle.pack('N', #header) .. header
        for i = 1, #message do
            conn:write(message:sub(i, i))
        end

        assert(conn:readable(1), "Recv timeout")
        local resp = assert(conn:recv(1024))
        local _, pos = msgpack.decode(resp)
        t.assert_equals(pos, 6)
        local body = msgpack.decode(resp, pos)

        t.assert_equals(body[0x00], 0x00) -- iproto_ok
        t.assert_equals(body[0x01], 1337) -- iproto_sync
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = socket.tcp_connect('127.0.0.1', 13301)
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = socket.tcp_connect('127.0.0.1', 13302)
    check_conn(conn_box)
    conn_box:close()
end

function g.test_invalid_serialization()
    -- Tarantool iproto protocol describes unified packet structure
    -- as follows:
    --
    -- 0        5
    -- +--------+ +============+ +===================================+
    -- | BODY + | |            | |                                   |
    -- | HEADER | |   HEADER   | |               BODY                |
    -- |  SIZE  | |            | |                                   |
    -- +--------+ +============+ +===================================+
    --   MP_INT       MP_MAP                     MP_MAP
    --
    -- It starts from 5-byte uint32 (0xCE)
    -- But python connector disregards it and uses mp_encode,
    -- which sometimes results in smaller types uint16/uint8
    -- or even FIXNUM
    --
    -- Remote control should still be able to handle this stream.

    local function check_conn(conn)
        assert(conn, errno.strerror())
        conn:read(128) -- greeting

        local header = msgpack.encode({
            [0x00] = 0x40, -- code = ping
            [0x01] = 0x77, -- sync = 0x77
        })
        local message = pickle.pack('B', #header) .. header
        conn:write(message)

        assert(conn:readable(1), "Recv timeout")
        local resp = conn:recv(100)
        local _, pos = msgpack.decode(resp)
        t.assert_equals(pos, 6)
        local body = msgpack.decode(resp, pos)

        t.assert_equals(body[0x00], 0x00) -- iproto_ok
        t.assert_equals(body[0x01], 0x77) -- iproto_sync
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = socket.tcp_connect('127.0.0.1', 13301)
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = socket.tcp_connect('127.0.0.1', 13302)
    check_conn(conn_box)
    conn_box:close()
end

function g.test_large_payload()
    local _20MiB = {}
    for _ = 1, 20*1024 do
        local chunk = digest.urandom(512):hex()
        assert(#chunk == 1024)
        table.insert(_20MiB, chunk)
    end

    local function check_conn(conn)
        t.assert_equals(conn:eval('return #(...)', {_20MiB}), 20*1024)
    end

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:3.141592@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()
end

function g.test_async()
    rc_start(13301)
    local conn = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    local future = conn:call('get_local_secret', nil, {is_async=true})
    t.assert_equals(future:is_ready(), false)
    t.assert_equals(future:wait_result(), {secret})
    t.assert_equals(future:is_ready(), true)
    t.assert_equals(future:result(), {secret})

    local future = conn:call('get_local_secret', nil, {is_async=true})
    t.assert_equals(conn:call('math.pow', {2, 6}), 64)
    t.assert_equals(future:wait_result(), {secret})
end

function g.test_bad_username()
    local function check_conn(conn)
        t.assert_equals(conn.error, "User 'bad-user' is not found")
        t.assert_equals(conn.state, "error")
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('bad-user@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('bad-user@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_bad_password()
    local function check_conn(conn)
        t.assert_equals(conn.error, "Incorrect password supplied for user 'superuser'")
        t.assert_equals(conn.state, "error")
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:bad-password@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:bad-password@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_guest()
    local function check_conn(conn)
        t.assert_not(conn.error)
        t.assert_error_msg_contains(
            "Execute access to function 'bad_function' is denied for user 'guest'",
            conn.call, conn, 'bad_function'
        )

        t.assert_not(conn.error)
        t.assert_error_msg_contains(
            "Execute access to function 'get_local_secret' is denied for user 'guest'",
            conn.call, conn, 'get_local_secret'
        )

        t.assert_not(conn.error)
        t.assert_error_msg_contains(
            "Execute access to function '_G.get_local_secret' is denied for user 'guest'",
            conn.call, conn, '_G.get_local_secret'
        )

        t.assert_not(conn.error)
        t.assert_error_msg_contains(
            "Execute access to universe '' is denied for user 'guest'",
            conn.eval, conn, 'end'
        )

        t.assert_not(conn.error)
        t.assert_error_msg_contains(
            "Execute access to universe '' is denied for user 'guest'",
            conn.eval, conn, 'return 42'
        )

        t.assert_not(conn.error)
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_call()
    local function check_conn(conn)
        t.assert_not(conn.error)
        t.assert_equals(conn:call('get_local_secret'), secret)
        t.assert_equals(conn:call('_G.get_local_secret'), secret)
        t.assert_equals(conn:call('_G._G.get_local_secret'), secret)
        t.assert_equals(conn:call('indexed.get_local_secret'), secret)
        t.assert_equals(conn:call('callable'), secret)
        t.assert_equals(conn:call('object:method'), nil)
        t.assert_equals(conn:call('math.pow', {2, 4}), 16)
        t.assert_equals(conn:call('_G.math.pow', {2, 5}), 32)

        t.assert_error_msg_contains(
            "Procedure '' is not defined",
            conn.call, conn, ''
        )

        t.assert_error_msg_contains(
            "Procedure '.' is not defined",
            conn.call, conn, '.'
        )

        t.assert_error_msg_contains(
            "Procedure ':' is not defined",
            conn.call, conn, ':'
        )

        t.assert_error_msg_contains(
            "Procedure 'bad_function' is not defined",
            conn.call, conn, 'bad_function'
        )

        t.assert_error_msg_contains(
            "attempt to call a table value",
            conn.call, conn, 'uncallable'
        )

        t.assert_error_msg_contains(
            "Procedure 'math.pow.unknown' is not defined",
            conn.call, conn, 'math.pow.unknown'
        )

        t.assert_error_msg_contains(
            "Procedure 'math.pi' is not defined",
            conn.call, conn, 'math.pi'
        )

        t.assert_error_msg_contains(
            "Procedure '_G.bad_function' is not defined",
            conn.call, conn, '_G.bad_function'
        )

        t.assert_error_msg_contains(
            "Procedure '.get_local_secret' is not defined",
            conn.call, conn, '.get_local_secret'
        )

        t.assert_error_msg_contains(
            "Procedure '_G..get_local_secret' is not defined",
            conn.call, conn, '_G..get_local_secret'
        )

        t.assert_error_msg_contains(
            "Procedure '_G:object:method' is not defined",
            conn.call, conn, '_G:object:method'
        )

        t.assert_error_msg_contains(
            "Use object:method instead",
            conn.call, conn, 'object.method'
        )

        t.assert_equals({conn:call('multireturn')}, {box.NULL, "Artificial Error", 3})
        t.assert_equals({conn:call('varargs')}, {})
        t.assert_equals({conn:call('varargs', {1, nil, 'nil-gap'})}, {1, box.NULL, 'nil-gap'})
        t.assert_equals({conn:call('varargs', {2, box.NULL, 'null-gap'})}, {2, box.NULL, 'null-gap'})

        -- handled by conn.call, raises an error before sending data to server
        t.assert_error_msg_contains(
            "Tuple/Key must be MsgPack array",
            conn.call, conn, 'varargs', {[16] = 'mp_map'}
        )
        t.assert_error_msg_contains(
            "Tuple/Key must be MsgPack array",
            conn.call, conn, 'varargs', {xxxx = 'mp_map'}
        )

        local ok, err = pcall(conn.call, conn, 'eval',
            {'error("ScriptError", 0)'}
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'ScriptError')

        local ok, err = pcall(conn.call, conn, 'eval', {[1] = [[
            local err = setmetatable({}, {
                __tostring = function() return "TableError" end,
            })
            error(err)
        ]]})
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'TableError')

        local ok, err = pcall(conn.call, conn, 'eval',
            {'box.error(box.error.PROTOCOL, "BoxError")'}
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.code, box.error.PROTOCOL)
        t.assert_equals(err.message, 'BoxError')

        t.assert_not(conn.error)

        local ok, err = pcall(conn.call, conn,
            'box.ctl.wait_ro', {0.001}
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'timed out')

        t.assert_not(conn.error)
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:3.141592@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_eval()
    local function check_conn(conn)
        t.assert_not(conn.error)
        t.assert_equals({conn:eval('return')}, {nil})
        t.assert_equals({conn:eval('return nil')}, {box.NULL})
        t.assert_equals({conn:eval('return nil, 1, nil')}, {box.NULL, 1, box.NULL})
        t.assert_equals({conn:eval('return 2 + 2')}, {4})
        t.assert_equals({conn:eval('return "multi", nil, false')}, {"multi", box.NULL, false})
        t.assert_equals({conn:eval('return get_local_secret()')}, {secret})
        t.assert_equals({conn:eval('return ...', {1, nil, 'nil-gap'})}, {1, box.NULL, 'nil-gap'})
        t.assert_equals({conn:eval('return ...', {2, box.NULL, 'null-gap'})}, {2, box.NULL, 'null-gap'})
        t.assert_equals({conn:eval('return ...', {3, nil})}, {3})

        t.assert_error_msg_contains(
            "unexpected symbol near ','",
            conn.eval, conn, ','
        )

        t.assert_error_msg_contains(
            "'end' expected near '<eof>'",
            conn.eval, conn, 'do'
        )

        local ok, err = pcall(conn.eval, conn,
            'error("ScriptError", 0)'
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'ScriptError')

        local ok, err = pcall(conn.eval, conn, [[
            local err = setmetatable({}, {
                __tostring = function() return "TableError" end,
            })
            error(err)
        ]])
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'TableError')

        local ok, err = pcall(conn.eval, conn,
            'box.error(box.error.PROTOCOL, "BoxError")'
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.code, box.error.PROTOCOL)
        t.assert_equals(err.message, 'BoxError')

        local ok, err = pcall(conn.eval, conn,
            'box.ctl.wait_ro(0.001)'
        )
        t.assert_not(ok)
        t.assert_equals(type(err), 'cdata')
        t.assert_equals(err.message, 'timed out')

        t.assert_not(conn.error)
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:3.141592@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_timeout()
    local function check_conn(conn)
        t.assert_not(conn.error)

        t.assert_error_msg_contains(
            "Timeout exceeded",
            conn.eval, conn, 'require("fiber").sleep(1)', nil,
            {timeout = 0.2}
        )

        t.assert_equals(
            conn:call('get_local_secret', nil, {timeout = 0.2}),
            secret
        )

        t.assert_equals(conn:call('math.pow', {2, 8}), 256)

        t.assert_not(conn.error)
    end

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local conn_rc = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    check_conn(conn_rc)
    conn_rc:close()

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13302'})
    local conn_box = assert(netbox.connect('superuser:3.141592@localhost:13302'))
    check_conn(conn_box)
    conn_box:close()
end

function g.test_switch_box_to_rc()
    local uri = 'superuser:3.141592@localhost:13301'

    box.cfg({listen = '127.0.0.1:13301'})
    local conn_1 = assert(netbox.connect(uri))
    t.assert_not(conn_1.error)
    t.assert_equals(conn_1.state, "active")
    t.assert_equals(conn_1.peer_uuid, box.info.uuid)

    box.cfg({listen = box.NULL})
    local conn_2 = assert(netbox.connect(uri))
    t.assert_equals(conn_2.state, "error")
    t.assert_equals(conn_2.peer_uuid, nil)
    local valid_errors = {
        ["Connection refused"] = true,
        ["Network is unreachable"] = true, -- inside docker
    }
    t.assert(valid_errors[conn_2.error])

    -- conn_1 is still alive and useful
    t.assert_not(conn_1.error)
    t.assert_equals(conn_1.state, "active")
    t.assert_equals(conn_1:call('get_local_secret'), secret)

    -- rc can be started on the same port
    rc_start(13301)
    local conn_rc = assert(netbox.connect(uri))
    t.assert_not(conn_rc.error)
    t.assert_equals(conn_rc.state, "active")
    t.assert_equals(conn_rc:call('get_local_secret'), secret)
    t.assert_equals(conn_rc.peer_uuid, "00000000-0000-0000-0000-000000000000")
end

function g.test_switch_rc_to_box()
    local uri = 'superuser:3.141592@localhost:13301'

    rc_start(13301)
    local conn_rc = assert(netbox.connect(uri))
    t.assert_not(conn_rc.error)
    t.assert_equals(conn_rc.state, "active")
    t.assert_equals(conn_rc.peer_uuid, "00000000-0000-0000-0000-000000000000")

    -- swap remote control with real iproto
    t.assert_equals(conn_rc:eval([[
        local remote_control = require('cartridge.remote-control')
        remote_control.stop()
        box.cfg({listen = '127.0.0.1:13301'})
        return box.info.uuid
    ]]), box.info.uuid)

    -- remote control still works
    t.assert_not(conn_rc.error)
    t.assert_equals(conn_rc.state, "active")
    t.assert_equals(conn_rc:call('get_local_secret'), secret)

    -- iproto connection can be established
    local conn_box = assert(netbox.connect(uri))
    t.assert_not(conn_box.error)
    t.assert_equals(conn_box.state, "active")
    t.assert_equals(conn_box.peer_uuid, box.info.uuid)
    t.assert_equals(conn_box:call('get_local_secret'), secret)
end

function g.test_reconnect()
    local uri = 'superuser:3.141592@localhost:13301'

    local conn = assert(netbox.connect(uri, {
        wait_connected = false,
        reconnect_after = 0.2,
    }))

    helpers.retrying({}, function()
        t.assert_covers(conn, {state = 'error_reconnect'})
        t.assert_covers({
            [errno.strerror(errno.ECONNREFUSED)] = true,
            [errno.strerror(errno.ENETUNREACH)] = true,
        }, {[conn.error] = true})
    end)

    rc_start(13301)
    t.assert_equals(conn:call('get_local_secret'), secret)

    remote_control.stop()
    remote_control.drop_connections()

    helpers.retrying({}, function()
        t.assert_covers(conn, {
            error = 'Peer closed',
            state = 'error_reconnect',
        })
    end)

    box.cfg({listen = '127.0.0.1:13301'})

    helpers.retrying({}, function()
        t.assert_covers(conn, {
            error = nil,
            state = 'active',
        })
    end)
end

local function lsof(pid)
    local f = io.popen('lsof -Pi -a -p ' .. pid)
    local lsof = f:read('*all'):strip():split('\n')
    table.remove(lsof, 1) -- heading
    return lsof
end

function g.test_socket_gc()
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)

    local initial_lsof = lsof(tarantool.pid())

    for i = 1, 16 do
        local s = socket.tcp_connect('127.0.0.1', 13301)
        t.assert(s, string.format('socket #%s: %s', i, errno.strerror()))
        s:close()
        fiber.sleep(0)
    end

    -- One socket still remains in CLOSE_WAIT state
    local current_lsof = lsof(tarantool.pid())
    t.assert_equals(#current_lsof, #initial_lsof + 1,
        'Too many open sockets\n' .. table.concat(current_lsof, '\n')
    )

    remote_control.accept({username = username, password = password})
    fiber.sleep(0)

    -- It disappears after accept()
    t.assert_equals(lsof(tarantool.pid()), initial_lsof)
end

function g.test_fd_cloexec()
    local utils = require('cartridge.utils')

    -- Bind remote control
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals({ok, err}, {true, nil})

    -- Connect it
    local client = socket.tcp_connect('127.0.0.1', 13301)
    t.assert(client, errno.strerror())
    fiber.sleep(0)

    -- Client socket has to be managed by ourselves
    local client_fd = client:fd()
    utils.fd_cloexec(client_fd)

    local proc = t.Process:start('/usr/bin/env', {'sleep', '1'})
    fiber.sleep(0)

    print()
    log.info('Parent FDs:\n%s', table.concat(lsof(tarantool.pid()), '\n'))
    log.info('Child FDs:\n%s', table.concat(lsof(proc.pid), '\n'))

    -- Check that port can be bound again
    client:close()
    remote_control.stop()
    remote_control.drop_connections()
    local ok, err = remote_control.bind('127.0.0.1', 13301)
    t.assert_equals({ok, err}, {true, nil})

    -- Check invalid usage
    local ok, err = utils.fd_cloexec(client_fd)
    t.assert_equals(ok, nil)
    t.assert_covers(err, {
        class_name = 'FcntlError',
        err = 'fcntl(F_GETFD) failed: Bad file descriptor',
    })
end
