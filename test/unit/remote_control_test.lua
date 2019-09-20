local t = require('luatest')
local g = t.group('remote_control')

local fio = require('fio')
local digest = require('digest')
local netbox = require('net.box')
local remote_control = require('cartridge.remote-control')
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
_G.object = {}
function _G.object:method()
    assert(self == _G.object, "Use object:method instead")
end

function g.before_all()
    g.datadir = fio.tempdir()
    box.cfg({
        memtx_dir = g.datadir,
        wal_mode = 'none',
    })
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
end

function g.after_all()
    box.cfg({listen = box.NULL})
    fio.rmtree(g.datadir)
    g.datadir = nil
end

local function rc_start(port)
    local ok, err = remote_control.start('127.0.0.1', port, {
        username = username,
        password = password,
    })

    t.assertEquals(err, nil)
    t.assertEquals(ok, true)
end

function g.teardown()
    box.cfg({listen = box.NULL})
    remote_control.stop()
    collectgarbage() -- cleanup sockets, created with netbox.connect
end

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
    local cred = {
        username = username,
        password = password,
    }

    rc_start(13301)
    box.cfg({listen = box.NULL})
    local ok, err = remote_control.start('127.0.0.1', 13301, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    t.assertEquals(err.err, "Already running")

    remote_control.stop()
    box.cfg({listen = '127.0.0.1:13301'})
    local ok, err = remote_control.start('127.0.0.1', 13301, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    t.assertEquals(err.err,
        "Can't start server: " .. errno.strerror(errno.EADDRINUSE)
    )

    remote_control.stop()
    box.cfg({listen = box.NULL})

    local ok, err = remote_control.start('0.0.0.0', -1, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    -- MacOS and Linux returns different errno
    assertStrOneOf(err.err, {
        "Can't start server: " .. errno.strerror(errno.EIO),
        "Can't start server: " .. errno.strerror(errno.EAFNOSUPPORT),
    })

    local ok, err = remote_control.start('255.255.255.255', 13301, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    t.assertEquals(err.err,
        "Can't start server: " .. errno.strerror(errno.EINVAL)
    )

    local ok, err = remote_control.start('google.com', 13301, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    t.assertEquals(err.err,
        "Can't start server: " .. errno.strerror(errno.EADDRNOTAVAIL)
    )

    local ok, err = remote_control.start('8.8.8.8', 13301, cred)
    t.assertNil(ok)
    t.assertEquals(err.class_name, "RemoteControlError")
    t.assertEquals(err.err,
        "Can't start server: " .. errno.strerror(errno.EADDRNOTAVAIL)
    )

    local ok, err = remote_control.start('localhost', 13301, cred)
    t.assertTrue(ok)
    t.assertNil(err)
    remote_control.stop()
end

function g.test_peer_uuid()
    rc_start(13301)
    local conn = assert(netbox.connect('localhost:13301'))
    t.assertEquals(conn.peer_uuid, "00000000-0000-0000-0000-000000000000")
end

function g.test_auth()
    rc_start(13301)
    local conn = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    t.assertNil(conn.error)
    t.assertEquals(conn.state, "active")
end

function g.test_ping()
    rc_start(13301)
    local conn = assert(netbox.connect('localhost:13301'))
    t.assertTrue(conn:ping())
end

function g.test_async()
    rc_start(13301)
    local conn = assert(netbox.connect('superuser:3.141592@localhost:13301'))
    local future = conn:call('get_local_secret', nil, {is_async=true})
    t.assertFalse(future:is_ready())
    t.assertEquals(future:wait_result(), {secret})
    t.assertTrue(future:is_ready())
    t.assertEquals(future:result(), {secret})

    local future = conn:call('get_local_secret', nil, {is_async=true})
    t.assertEquals(conn:call('math.pow', {2, 6}), 64)
    t.assertEquals(future:wait_result(), {secret})
end

function g.test_bad_username()
    local function check_conn(conn)
        t.assertEquals(conn.error, "User 'bad-user' is not found")
        t.assertEquals(conn.state, "error")
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
        t.assertEquals(conn.error, "Incorrect password supplied for user 'superuser'")
        t.assertEquals(conn.state, "error")
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
        t.assertNil(conn.error)
        t.assertErrorMsgContains(
            "Execute access to function 'bad_function' is denied for user 'guest'",
            conn.call, conn, 'bad_function'
        )

        t.assertNil(conn.error)
        t.assertErrorMsgContains(
            "Execute access to function 'get_local_secret' is denied for user 'guest'",
            conn.call, conn, 'get_local_secret'
        )

        t.assertNil(conn.error)
        t.assertErrorMsgContains(
            "Execute access to function '_G.get_local_secret' is denied for user 'guest'",
            conn.call, conn, '_G.get_local_secret'
        )

        t.assertNil(conn.error)
        t.assertErrorMsgContains(
            "Execute access to universe '' is denied for user 'guest'",
            conn.eval, conn, 'end'
        )

        t.assertNil(conn.error)
        t.assertErrorMsgContains(
            "Execute access to universe '' is denied for user 'guest'",
            conn.eval, conn, 'return 42'
        )

        t.assertNil(conn.error)
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
        t.assertNil(conn.error)
        t.assertEquals(conn:call('get_local_secret'), secret)
        t.assertEquals(conn:call('_G.get_local_secret'), secret)
        t.assertEquals(conn:call('_G._G.get_local_secret'), secret)
        t.assertEquals(conn:call('indexed.get_local_secret'), secret)
        t.assertEquals(conn:call('callable'), secret)
        t.assertEquals(conn:call('object:method'), nil)
        t.assertEquals(conn:call('math.pow', {2, 4}), 16)
        t.assertEquals(conn:call('_G.math.pow', {2, 5}), 32)

        t.assertErrorMsgContains(
            "Procedure '' is not defined",
            conn.call, conn, ''
        )

        t.assertErrorMsgContains(
            "Procedure '.' is not defined",
            conn.call, conn, '.'
        )

        t.assertErrorMsgContains(
            "Procedure ':' is not defined",
            conn.call, conn, ':'
        )

        t.assertErrorMsgContains(
            "Procedure 'bad_function' is not defined",
            conn.call, conn, 'bad_function'
        )

        t.assertErrorMsgContains(
            "attempt to call a table value",
            conn.call, conn, 'uncallable'
        )

        t.assertErrorMsgContains(
            "Procedure 'math.pow.unknown' is not defined",
            conn.call, conn, 'math.pow.unknown'
        )

        t.assertErrorMsgContains(
            "Procedure 'math.pi' is not defined",
            conn.call, conn, 'math.pi'
        )

        t.assertErrorMsgContains(
            "Procedure '_G.bad_function' is not defined",
            conn.call, conn, '_G.bad_function'
        )

        t.assertErrorMsgContains(
            "Procedure '.get_local_secret' is not defined",
            conn.call, conn, '.get_local_secret'
        )

        t.assertErrorMsgContains(
            "Procedure '_G..get_local_secret' is not defined",
            conn.call, conn, '_G..get_local_secret'
        )

        t.assertErrorMsgContains(
            "Procedure '_G:object:method' is not defined",
            conn.call, conn, '_G:object:method'
        )

        t.assertErrorMsgContains(
            "Use object:method instead",
            conn.call, conn, 'object.method'
        )

        t.assertEquals({conn:call('multireturn')}, {box.NULL, "Artificial Error", 3})
        t.assertEquals({conn:call('varargs')}, {})
        t.assertEquals({conn:call('varargs', {1, nil, 'nil-gap'})}, {1, box.NULL, 'nil-gap'})
        t.assertEquals({conn:call('varargs', {2, box.NULL, 'null-gap'})}, {2, box.NULL, 'null-gap'})

        -- handled by conn.call, raises an error before sending data to server
        t.assertErrorMsgContains(
            "Tuple/Key must be MsgPack array",
            conn.call, conn, 'varargs', {[16] = 'mp_map'}
        )
        t.assertErrorMsgContains(
            "Tuple/Key must be MsgPack array",
            conn.call, conn, 'varargs', {xxxx = 'mp_map'}
        )

        t.assertNil(conn.error)
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
        t.assertNil(conn.error)
        t.assertEquals({conn:eval('return')}, {nil})
        t.assertEquals({conn:eval('return nil')}, {box.NULL})
        t.assertEquals({conn:eval('return nil, 1, nil')}, {box.NULL, 1, box.NULL})
        t.assertEquals({conn:eval('return 2 + 2')}, {4})
        t.assertEquals({conn:eval('return "multi", nil, false')}, {"multi", box.NULL, false})
        t.assertEquals({conn:eval('return get_local_secret()')}, {secret})
        t.assertEquals({conn:eval('return ...', {1, nil, 'nil-gap'})}, {1, box.NULL, 'nil-gap'})
        t.assertEquals({conn:eval('return ...', {2, box.NULL, 'null-gap'})}, {2, box.NULL, 'null-gap'})
        t.assertEquals({conn:eval('return ...', {3, nil})}, {3})

        t.assertErrorMsgContains(
            "unexpected symbol near ','",
            conn.eval, conn, ','
        )

        t.assertErrorMsgContains(
            "'end' expected near '<eof>'",
            conn.eval, conn, 'do'
        )

        t.assertErrorMsgContains(
            "ScriptError",
            conn.eval, conn, 'error("ScriptError")'
        )

        t.assertNil(conn.error)
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
        t.assertNil(conn.error)

        t.assertErrorMsgContains(
            "Timeout exceeded",
            conn.eval, conn, 'require("fiber").sleep(1)', nil,
            {timeout = 0.2}
        )

        -- WARNING behavior differs here
        if conn.peer_uuid == "00000000-0000-0000-0000-000000000000" then
            -- connection handler is still blocked
            t.assertErrorMsgContains(
                "Timeout exceeded",
                conn.call, conn, 'get_local_secret', nil, {timeout = 0.2}
            )
        else
            t.assertEquals(
                conn:call('get_local_secret', nil, {timeout = 0.2}),
                secret
            )
        end

        t.assertEquals(conn:call('math.pow', {2, 8}), 256)

        t.assertNil(conn.error)
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
    t.assertNil(conn_1.error)
    t.assertEquals(conn_1.state, "active")
    t.assertEquals(conn_1.peer_uuid, box.info.uuid)

    box.cfg({listen = box.NULL})
    local conn_2 = assert(netbox.connect(uri))
    t.assertEquals(conn_2.state, "error")
    t.assertEquals(conn_2.peer_uuid, nil)
    local valid_errors = {
        ["Connection refused"] = true,
        ["Network is unreachable"] = true, -- inside docker
    }
    t.assertTrue(valid_errors[conn_2.error])

    -- conn_1 is still alive and useful
    t.assertNil(conn_1.error)
    t.assertEquals(conn_1.state, "active")
    t.assertEquals(conn_1:call('get_local_secret'), secret)

    -- rc can be started on the same port
    rc_start(13301)
    local conn_rc = assert(netbox.connect(uri))
    t.assertNil(conn_rc.error)
    t.assertEquals(conn_rc.state, "active")
    t.assertEquals(conn_rc:call('get_local_secret'), secret)
    t.assertEquals(conn_rc.peer_uuid, "00000000-0000-0000-0000-000000000000")
end

function g.test_switch_rc_to_box()
    local uri = 'superuser:3.141592@localhost:13301'

    rc_start(13301)
    local conn_rc = assert(netbox.connect(uri))
    t.assertNil(conn_rc.error)
    t.assertEquals(conn_rc.state, "active")
    t.assertEquals(conn_rc.peer_uuid, "00000000-0000-0000-0000-000000000000")

    -- swap remote control with real iproto
    t.assertEquals(conn_rc:eval([[
        local remote_control = require('cartridge.remote-control')
        remote_control.stop()
        box.cfg({listen = '127.0.0.1:13301'})
        return box.info.uuid
    ]]), box.info.uuid)

    -- remote control still works
    t.assertNil(conn_rc.error)
    t.assertEquals(conn_rc.state, "active")
    t.assertEquals(conn_rc:call('get_local_secret'), secret)

    -- iproto connection can be established
    local conn_box = assert(netbox.connect(uri))
    t.assertNil(conn_box.error)
    t.assertEquals(conn_box.state, "active")
    t.assertEquals(conn_box.peer_uuid, box.info.uuid)
    t.assertEquals(conn_box:call('get_local_secret'), secret)
end
