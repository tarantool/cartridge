local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local netbox = require('net.box')

local ClientError  = errors.new_class('ClientError')
local SessionError = errors.new_class('SessionError')

local function acquire_lock(session, lock_args)
    checks('stateboard_session', {
        uuid = 'string',
        uri = 'string',
    })
    assert(session.connection ~= nil)

    local lock_acquired, err = errors.netbox_call(session.connection,
        'acquire_lock', {lock_args},
        {timeout = session.call_timeout}
    )
    if lock_acquired == nil then
        return nil, SessionError:new(err)
    end

    session.lock_acquired = lock_acquired
    return lock_acquired
end

local function get_lock_delay(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    if session.lock_delay ~= nil then
        return session.lock_delay
    end

    local lock_delay, err = errors.netbox_call(session.connection,
        'get_lock_delay', nil,
        {timeout = session.call_timeout}
    )
    if lock_delay == nil then
        return nil, SessionError:new(err)
    end

    session.lock_delay = lock_delay
    return lock_delay
end

local function set_leaders(session, updates)
    checks('stateboard_session', 'table')
    assert(session.connection ~= nil)

    local ok, err = errors.netbox_call(session.connection,
        'set_leaders', {updates},
        {timeout = session.call_timeout}
    )

    if ok == nil then
        return nil, SessionError:new(err)
    end
    return ok
end

local function get_leaders(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    local leaders, err = errors.netbox_call(session.connection,
        'get_leaders', nil,
        {timeout = session.call_timeout}
    )

    if leaders == nil then
        return nil, SessionError:new(err)
    end
    return leaders
end

local function get_coordinator(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    local coodinator, err = errors.netbox_call(session.connection,
        'get_coordinator', nil,
        {timeout = session.call_timeout}
    )

    if err ~= nil then
        return nil, SessionError:new(err)
    end
    return coodinator
end

local function is_locked(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    return session.connection:is_connected()
        and session.lock_acquired
end

local function is_alive(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    return session.connection.state ~= 'error'
        and session.connection.state ~= 'closed'
end

local function drop(session)
    checks('stateboard_session')
    assert(session.connection ~= nil)

    session.lock_acquired = false
    pcall(function()
        session.connection:close()
    end)
end

local session_mt = {
    __type = 'stateboard_session',
    __index = {
        is_alive = is_alive,
        is_locked = is_locked,
        acquire_lock = acquire_lock,
        set_leaders = set_leaders,
        get_leaders = get_leaders,
        get_lock_delay = get_lock_delay,
        get_coordinator = get_coordinator,
        drop = drop,
    },
}

local function get_session(client)
    checks('stateboard_client')

    if client.session ~= nil
    and client.session:is_alive() then
        return client.session
    end

    local connection = netbox.connect(client.uri, {
        user = 'client',
        password = client.password,
        wait_connected = false,
    })

    local session = {
        lock_acquired = false,
        call_timeout = client.call_timeout,
        connection = connection,
    }
    client.session = setmetatable(session, session_mt)
    return client.session
end

local function drop_session(client)
    checks('stateboard_client')
    if client.session ~= nil then
        client.session:drop()
        client.session = nil
    end
end

local function longpoll(client, timeout)
    checks('stateboard_client', 'number')

    local deadline = fiber.time() + timeout

    while true do
        local session = client:get_session()
        local timeout = deadline - fiber.time()

        local ret, err = errors.netbox_call(session.connection,
            'longpoll', {timeout},
            {timeout = timeout + client.call_timeout}
        )

        if ret ~= nil then
            return ret
        end

        if fiber.time() < deadline then
            fiber.sleep(client.call_timeout)
            -- continue
        else
            return nil, ClientError:new(err)
        end
    end
end

local client_mt = {
    __type = 'stateboard_client',
    __index = {
        longpoll = longpoll,
        get_session = get_session,
        drop_session = drop_session,
    },
}

local function new(opts)
    checks({
        uri = 'string',
        password = 'string',
        call_timeout = 'number',
    })

    local client = {
        state_provider = 'tarantool',
        session = nil,
        uri = opts.uri,
        password = opts.password,
        call_timeout = opts.call_timeout,
    }
    return setmetatable(client, client_mt)
end

return {
    new = new,
}
