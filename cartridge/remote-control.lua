--- Tarantool remote control server.
--
-- Allows to control an instance over TCP by `net.box` `call` and `eval`.
-- The server is designed as a partial replacement for the **iproto** protocol.
-- It's most useful when `box.cfg` wasn't configured yet.
--
-- Other `net.box` features aren't supported and will never be.
--
-- (**Added** in v0.10.0-2)
--
-- @module cartridge.remote-control
-- @local

local log = require('log')
local ffi = require('ffi')
local errno = require('errno')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local socket = require('socket')
local digest = require('digest')
local pickle = require('pickle')
local msgpack = require('msgpack')
local utils = require('cartridge.utils')
local _, sslsocket = pcall(require, 'cartridge.sslsocket')
local vars = require('cartridge.vars').new('cartridge.remote-control')

vars:new('server')
vars:new('username')
vars:new('password')
vars:new('handlers', {})
vars:new('accept', false)
vars:new('accept_cond', fiber.cond())
vars:new('suspend', false)
vars:new('suspend_cond', fiber.cond())

local RemoteControlError = errors.new_class('RemoteControlError')
local error_t = ffi.typeof('struct error')

local function _pack(...)
    local ret = {...}
    for i = 1, select('#', ...) do
        if ret[i] == nil then
            ret[i] = msgpack.NULL
        end
    end

    return ret
end

local function rc_eval(code, args)
    checks('string', 'table')
    local fun = assert(loadstring(code, 'eval'))
    return _pack(fun(unpack(args)))
end

local call_loadproc = box.internal.call_loadproc
local function pack_tail(status, ...)
    if not status then
        return status, ...
    end
    return status, _pack(...)
end

local function rc_call(function_path, ...)
    checks('string')
    local exists, proc, obj = pcall(call_loadproc, function_path)
    if not exists then
        return false, proc
    end

    if obj ~= nil then
        return pack_tail(pcall(proc, obj, ...))
    else
        return pack_tail(pcall(proc, ...))
    end
end

local iproto_code = {
    [0x01] = "iproto_select",
    [0x02] = "iproto_insert",
    [0x03] = "iproto_replace",
    [0x04] = "iproto_update",
    [0x05] = "iproto_delete",
    [0x06] = "iproto_call_16",
    [0x07] = "iproto_auth",
    [0x08] = "iproto_eval",
    [0x09] = "iproto_upsert",
    [0x0a] = "iproto_call",
    [0x0b] = "iproto_execute",
    [0x0c] = "iproto_nop",
    [0x0d] = "iproto_type_stat_max",
    [0x40] = "iproto_ping",
    [0x41] = "iproto_join",
    [0x42] = "iproto_subscribe",
    [0x43] = "iproto_request_vote",
    [0x44] = "iproto_vote",
}

local function mpenc_uint32(n)
    return pickle.pack('bN', 0xCE, n)
end

local function reply_ok(s, sync, data)
    checks('?', 'number', '?table')

    local header = msgpack.encode({
        [0x00] = 0x00, -- iproto_ok
        [0x05] = 0x00, -- iproto_schema_id
        [0x01] = sync, -- iproto_sync
    })

    if data == nil then
        s:write(mpenc_uint32(#header) .. header)
    else
        local payload = msgpack.encode({[0x30] = data})
        s:write(mpenc_uint32(#header + #payload) .. header .. payload)
    end
end

local function reply_err(s, sync, ecode, efmt, ...)
    checks('?', 'number', 'number', 'string')

    local header = msgpack.encode({
        [0x00] = 0x8000+ecode, -- iproto_type_error
        [0x05] = 0x00, -- iproto_schema_id
        [0x01] = sync, -- iproto_sync
    })
    local payload = msgpack.encode({
        [0x31] = efmt:format(...)
    })

    s:write(mpenc_uint32(#header + #payload) .. header .. payload)
end

local function communicate_async(handler, s, sync, fn, ...)
    local task = fiber.self()
    task:name(handler:name())
    task.storage.handler = handler
    task.storage.session = handler.storage.session
    handler.storage.tasks[task] = true

    local ok, ret = fn(...)
    if ok then
        reply_ok(s, sync, ret)
    elseif ffi.istype(error_t, ret) then
        local code = ret.code
        if code == nil and ret.errno ~= nil then
            code = box.error.SYSTEM
        end
        reply_err(s, sync, code, ret.message)
    else
        reply_err(s, sync, box.error.PROC_LUA, tostring(ret))
    end

    handler.storage.tasks[task] = nil

    -- The connection was dropped and the last response was sent.
    -- Stop the communication and close the socket.
    if vars.handlers[s] == nil and next(handler.storage.tasks) == nil then
        s:close() -- may raise, but nobody cares
    end
end

local function communicate(s)
    local ok, buf = pcall(s.read, s, 5)
    if not ok or buf == nil or buf == '' then
        log.info('Peer closed when read packet size')
        return false
    end

    local size, pos = msgpack.decode(buf)
    local ok, _tail = pcall(s.read, s, pos-1 + size - #buf)
    if not ok or _tail == nil or _tail == '' then
        log.info('Peer closed')
        return false
    else
        buf = buf .. _tail
    end

    local header, pos = msgpack.decode(buf, pos)
    if header == nil or type(header) ~= 'table' then
        log.info("Invalid header in messagepack")
        return false
    end
    local body = nil
    if pos < #buf then
        body = msgpack.decode(buf, pos)
    end

    while vars.suspend do
        vars.suspend_cond:wait(1)
    end

    local code = header[0x00]
    local sync = header[0x01]

    if iproto_code[code] == nil then
        -- Don't talk to strangers, it may confuse them.
        -- See https://github.com/tarantool/tarantool/issues/6451
        return false

    elseif iproto_code[code] == 'iproto_select' then
        reply_ok(s, sync, {})
        return true

    elseif iproto_code[code] == 'iproto_auth' then
        local username = body[0x23]
        if username ~= vars.username then
            reply_err(s, sync, box.error.ACCESS_DENIED,
                "User '%s' is not found", username
            )
            return false
        end

        local method, scramble = unpack(body[0x21])
        if method == 'chap-sha1' then
            local step_1 = digest.sha1(vars.password)
            local step_2 = digest.sha1(step_1)
            local step_3 = digest.sha1(s._client_salt:sub(1, 20) .. step_2)

            for i = 1, 20 do
                local ss = scramble:sub(i, i):byte()
                local s1 = step_1:sub(i, i):byte()
                local s3 = step_3:sub(i, i):byte()
                if ss ~= bit.bxor(s1, s3) then
                    reply_err(s, sync, box.error.ACCESS_DENIED,
                        "Incorrect password supplied for user '%s'", username
                    )
                    return false
                end
            end
        else
            reply_err(s, sync, box.error.UNSUPPORTED,
                "Authentication method '%s' isnt supported", method
            )
            return false
        end

        s._client_user = username
        s._authorized = true
        reply_ok(s, sync, nil)
        return true

    elseif iproto_code[code] == 'iproto_eval' then
        local code = body[0x27]
        local args = body[0x21]

        if not s._authorized then
            reply_err(s, sync, box.error.ACCESS_DENIED,
                "Execute access to universe '' is denied for user '%s'",
                s._client_user
            )
            return true
        end

        local handler = fiber.self()
        -- It's important to use `fiber.create` and not `fiber.new`
        -- because it reschedules the `handler` and doesn't affect
        -- execution order unless the async call yields.
        fiber.create(communicate_async, handler, s, sync,
            pcall, rc_eval, code, args
        )

        return true

    elseif iproto_code[code] == 'iproto_call' then
        local fn_name = body[0x22]
        local fn_args = body[0x21]

        if not s._authorized then
            reply_err(s, sync, box.error.ACCESS_DENIED,
                "Execute access to function '%s' is denied for user '%s'",
                fn_name, s._client_user
            )
            return true
        end

        local handler = fiber.self()
        -- It's important to use `fiber.create` and not `fiber.new`
        -- because it reschedules the `handler` and doesn't affect
        -- execution order unless the async call yields.
        fiber.create(communicate_async, handler, s, sync,
            rc_call, fn_name, unpack(fn_args)
        )

        return true

    elseif iproto_code[code] == 'iproto_nop' then
        reply_ok(s, sync, nil)
        return true

    elseif iproto_code[code] == 'iproto_ping' then
        reply_ok(s, sync, nil)
        return true

    else
        -- Don't talk to strangers, it may confuse them.
        -- See https://github.com/tarantool/tarantool/issues/6451
        return false
    end
end

local function rc_handle(s)
    utils.fd_cloexec(s:fd())

    local salt = digest.urandom(32)

    local greeting = string.format(
        '%-63s\n%-63s\n',
        'Tarantool 1.10.0 (Binary) 00000000-0000-0000-0000-000000000000',
        digest.base64_encode(salt)
    )

    local handler = fiber.self()
    handler.storage.tasks = {}
    vars.handlers[s] = handler
    s._client_user = 'guest'
    s._client_salt = salt

    -- When a client reconnects before the server started accepting
    -- requests it's reasonable to avoid waiting for one-second timeout.
    -- We wake up all the handlers so they could check if their
    -- sockets were closed.
    vars.accept_cond:broadcast()

    while not vars.accept do
        vars.accept_cond:wait(1)
        fiber.testcancel()

        -- Socket can become readable in two cases:
        -- 1. It was closed by the client. On the server side it stays
        --    in CLOSE_WAIT state. The server should close it and
        --    release asap.
        -- 2. Server received data even before it has sent the greeting.
        --    This case doesn't conform to Tarantool iproto protocol.
        if s:readable(0) then
            vars.handlers[s] = nil
            return
        end
    end

    local ok, err = s:write(greeting)
    if not ok then
        log.info(err)
    end

    while vars.handlers[s] ~= nil or next(handler.storage.tasks) ~= nil do
        local ok, err = RemoteControlError:pcall(communicate, s)
        if err ~= nil then
            log.error('%s', err)
        end

        if not ok then
            break
        end
    end
end

--- Init remote control server.
--
-- Bind the port but don't start serving connections yet.
--
-- @function bind
-- @local
-- @tparam string host
-- @tparam string|number port
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function bind(host, port, sslparams)
    checks('string|table', 'string|number', '?table')

    if vars.server ~= nil then
        return nil, RemoteControlError:new('Already running')
    end

    local usessl = type(sslparams) == 'table' and sslparams.transport == 'ssl'
    local server
    if usessl then
        if sslsocket == nil or sslsocket.ctx == nil then
            return nil, RemoteControlError:new('Unable to load SSL socket')
        end
        log.info("Remote control over ssl")
        local ok, ctx = pcall(sslsocket.ctx, ffi.C.TLS_server_method())
        if ok ~= true then
            return nil, RemoteControlError:new(ctx)
        end

        -- TODO
        -- SSL_CTX_set_default_passwd_cb(ssl_ctx, passwd_cb);
        -- SSL_CTX_set_min_proto_version(ssl_ctx, TLS1_2_VERSION) != 1 ||
        -- SSL_CTX_set_max_proto_version(ssl_ctx, TLS1_2_VERSION) != 1)

        local rc = sslsocket.ctx_use_private_key_file(ctx, sslparams.ssl_key_file, sslparams.ssl_password)
        if rc == false then
            local err = RemoteControlError:new(
                "Can't start server on %s:%s: %s %s",
                host, port, 'Private key is invalid or password mismatch', sslparams.ssl_key_file
            )
            return nil, err
        end
        rc = sslsocket.ctx_use_certificate_file(ctx, sslparams.ssl_cert_file)
        if rc == false then
            local err = RemoteControlError:new(
                "Can't start server on %s:%s: %s",
                host, port, 'Certificate is invalid'
            )
            return nil, err
        end
        if sslparams.ssl_ca_file ~= nil then
            rc = sslsocket.ctx_load_verify_locations(ctx, sslparams.ssl_ca_file)
            if rc == false then
                local err = RemoteControlError:new(
                    "Can't start server on %s:%s: %s",
                    host, port, 'CA file is invalid'
                )
                return nil, err
            end

            -- SSL_VERIFY_PEER = 0x01
            -- SSL_VERIFY_FAIL_IF_NO_PEER_CERT = 0x02
            sslsocket.ctx_set_verify(ctx, 0x01 + 0x02)
        end
        if sslparams.ssl_ciphers ~= nil then
            rc = sslsocket.ctx_set_cipher_list(ctx, sslparams.ssl_ciphers)
            if rc == false then
                local err = RemoteControlError:new(
                    "Can't start server on %s:%s: %s",
                    host, port, 'Ciphers is invalid'
                )
                return nil, err
            end
        end

        local timeout = sslparams.timeout or 60

        server = sslsocket.tcp_server(host, port, {
                name = 'remote_control',
                handler = rc_handle,
            }, timeout, ctx)
    else
        server = socket.tcp_server(host, port, {
            name = 'remote_control',
            handler = rc_handle,
        })
    end

    if not server then
        local err = RemoteControlError:new(
            "Can't start server on %s:%s: %s",
            host, port, errno.strerror()
        )
        return nil, err
    end

    -- Workaround for https://github.com/tarantool/tarantool/issues/5220.
    -- If tarantool uses logging into pipe, remote-control fd is
    -- inherited by the forked process and never closed. It makes further
    -- box.cfg listen to fail because address already in use.
    local ok, err = utils.fd_cloexec(server:fd())
    if ok == nil then
        log.warn('%s', err)
    end

    vars.server = server
    return true
end

--- Start remote control server.
-- To connect the server use regular `net.box` connection.
--
-- Access is restricted to the user with specified credentials,
-- which can be passed as `net_box.connect('username:password@host:port')`.
--
-- @function accept
-- @local
-- @tparam table credentials
-- @tparam string credentials.username
-- @tparam string credentials.password
local function accept(opts)
    checks({
        username = 'string',
        password = 'string',
    })

    vars.username = opts.username
    vars.password = opts.password
    vars.accept = true
    vars.accept_cond:broadcast()
end

--- Stop the server.
--
-- It doesn't interrupt any existing connections.
--
-- @function unbind
-- @local
local function stop()
    if vars.server == nil then
        return
    end

    vars.server:close()
    vars.server = nil
    vars.accept = false
end

--- Explicitly drop all established connections.
--
-- Close all the sockets except the one that triggered the function.
-- The last socket will be closed when all requests are processed.
--
-- @function drop_connections
-- @local
local function drop_connections()
    local handlers = table.copy(vars.handlers)
    table.clear(vars.handlers)

    for s, handler in pairs(handlers) do
        if handler ~= fiber.self().storage.handler then
            pcall(function() log.info('dropping %s', s) end)
            pcall(function() handler:cancel() end)
            pcall(function() s:close() end)
        end
    end
end

--- Pause to handle requests for all clients.
--
-- It doesn't interrupt any existing connections.
--
-- @function suspend
-- @local
local function suspend()
    if vars.server == nil or vars.accept == false then
        return
    end

    vars.suspend = true
    vars.suspend_cond:broadcast()
end

--- Resume to handle requests for all clients.
--
-- It doesn't interrupt any existing connections.
--
-- @function suspend
-- @local
local function resume()
    if vars.server == nil or vars.accept == false then
        return
    end

    vars.suspend = false
    vars.suspend_cond:broadcast()
end

return {
    bind = bind,
    accept = accept,
    stop = stop,
    drop_connections = drop_connections,
    suspend = suspend,
    resume = resume,
}
