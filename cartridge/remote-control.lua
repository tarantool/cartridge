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
local uuid_lib = require('uuid')
local msgpack = require('msgpack')
local utils = require('cartridge.utils')
local vars = require('cartridge.vars').new('cartridge.remote-control')

vars:new('server')
vars:new('username')
vars:new('password')
vars:new('handlers', {})
vars:new('accept', false)
vars:new('accept_cond', fiber.cond())

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

local function is_callable(fun)
    if type(fun) == 'function' then
        return true
    elseif type(fun) == 'table' then
        local mt = getmetatable(fun)
        return mt and mt.__call
    else
        return false
    end
end

local function rc_call(function_path, args)
    checks('string', 'table')

    local mod_path, delimiter, fun_name = function_path:match('^(.-)([%.%:]?)([_%w]*)$')

    local mod = _G
    if delimiter ~= '' then
        local mod_parts = string.split(mod_path, '.')
        for i = 1, #mod_parts do
            if type(mod) ~= 'table' then
                break
            end
            mod = mod[mod_parts[i]]
        end
    end

    if type(mod) ~= 'table'
    or not is_callable(mod[fun_name])
    then
        error(string.format(
            "Procedure '%s' is not defined", function_path
        ))
    end

    if delimiter == ':' then
        return _pack(mod[fun_name](mod, unpack(args)))
    else
        return _pack(mod[fun_name](unpack(args)))
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

local function communicate(s)
    local ok, buf = pcall(s.read, s, 5)
    if not ok or buf == nil or buf == '' then
        log.debug('Peer closed')
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
    local body = nil
    if pos < #buf then
        body = msgpack.decode(buf, pos)
    end

    local code = header[0x00]
    local sync = header[0x01]

    if iproto_code[code] == nil then
        -- reply_err(s, sync or 0, box.error.UNKNOWN,
        --     "Unknown iproto code 0x%02x", code
        -- )
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

        local ok, ret = pcall(rc_eval, code, args)
        if ok then
            reply_ok(s, sync, ret)
            return true
        elseif ffi.istype(error_t, ret) then
            local code = ret.code
            if code == nil and ret.errno ~= nil then
                code = box.error.SYSTEM
            end
            reply_err(s, sync, code, ret.message)
            return true
        else
            reply_err(s, sync, box.error.PROC_LUA, tostring(ret))
            return true
        end

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

        local ok, ret = pcall(rc_call, fn_name, fn_args)
        if ok then
            reply_ok(s, sync, ret)
            return true
        elseif ffi.istype(error_t, ret) then
            local code = ret.code
            if code == nil and ret.errno ~= nil then
                code = box.error.SYSTEM
            end
            reply_err(s, sync, code, ret.message)
            return true
        else
            reply_err(s, sync, box.error.PROC_LUA, tostring(ret))
            return true
        end


    elseif iproto_code[code] == 'iproto_nop' then
        reply_ok(s, sync, nil)
        return true

    elseif iproto_code[code] == 'iproto_ping' then
        reply_ok(s, sync, nil)
        return true

    else
        -- reply_err(s, sync, box.error.UNSUPPORTED,
        --     "Remote Control doesn't support %s", iproto_code[code]
        -- )
        return false
    end
end

local function rc_handle(s)
    utils.fd_cloexec(s:fd())

    local version = string.match(_TARANTOOL, "^([%d%.]+)") or '???'
    local salt = digest.urandom(32)

    local greeting = string.format(
        '%-63s\n%-63s\n',
        'Tarantool ' .. version .. ' (Binary) ' .. uuid_lib.NULL:str(),
        -- 'Tarantool 1.10.3 (Binary) f1f1ab41-eae1-475b-b4bd-3fa8dd067f4d',
        digest.base64_encode(salt)
    )

    vars.handlers[s] = fiber.self()
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

    s:write(greeting)

    while vars.handlers[s] do
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
local function bind(host, port)
    checks('string', 'string|number')

    if vars.server ~= nil then
        return nil, RemoteControlError:new('Already running')
    end

    local server = socket.tcp_server(host, port, {
        name = 'remote_control',
        handler = rc_handle,
    })

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
-- @function drop_connections
-- @local
local function drop_connections()
    local handlers = table.copy(vars.handlers)
    table.clear(vars.handlers)

    for s, handler in pairs(handlers) do
        if handler ~= fiber.self() then
            pcall(function() handler:cancel() end)
            pcall(function() s:close() end)
        end
    end
end

return {
    bind = bind,
    accept = accept,
    stop = stop,
    drop_connections = drop_connections,
}
