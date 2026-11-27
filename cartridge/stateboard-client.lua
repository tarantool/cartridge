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

local function set_leaders(session, updates, force)
    checks('stateboard_session', 'table', '?boolean')
    assert(session.connection ~= nil)

    local fn = force and 'force_appoint_leaders' or 'set_leaders'
    local ok, err = errors.netbox_call(session.connection,
        fn, {updates},
        {timeout = session.call_timeout}
    )

    if ok == nil then
        return nil, SessionError:new(err)
    end
    return ok
end

local function delete_replicasets(session, replicasets)
    checks('stateboard_session', 'table')
    assert(session.connection ~= nil)

    local ok, err = errors.netbox_call(session.connection,
        'delete_replicasets', {replicasets},
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

local function get_vclockkeepers(session)
    checks('stateboard_session')
    local keepers, err = errors.netbox_call(session.connection,
        'get_vclockkeepers', nil,
        {timeout = session.call_timeout}
    )

    if err ~= nil then
        return nil, SessionError:new(err)
    end
    return keepers
end

local function get_appointment(session, replicaset_uuid)
    checks('stateboard_session', 'string')
    local appointment, err = errors.netbox_call(session.connection,
        'get_appointment', {replicaset_uuid},
        {timeout = session.call_timeout}
    )

    if err ~= nil then
        return nil, SessionError:new(err)
    end
    return appointment
end

local function activate(session, replicaset_uuid, instance_uuid, appointment, vclock)
    checks('stateboard_session', 'string', 'string', '?table', 'table')
    local ok, err = errors.netbox_call(session.connection, 'activate', {
        replicaset_uuid, instance_uuid,
        appointment and appointment.revision, appointment and appointment.keeper_revision, vclock,
    }, {timeout = session.call_timeout})

    if ok == nil then
        return nil, SessionError:new(err)
    end
    return true
end

local function get_vclockkeeper(session, replicaset_uuid)
    checks('stateboard_session', 'string')
    local vclockkeeper, err = errors.netbox_call(session.connection,
        'get_vclockkeeper', {replicaset_uuid},
        {timeout = session.call_timeout}
    )

    if err ~= nil then
        return nil, SessionError:new(err)
    end

    if vclockkeeper == nil then
        return nil, nil, 0
    end

    local ordinal = vclockkeeper.ordinal
    vclockkeeper.ordinal = nil
    return vclockkeeper, nil, ordinal
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
        get_vclockkeeper = get_vclockkeeper,
        get_vclockkeepers = get_vclockkeepers,
        get_appointment = get_appointment,
        activate = activate,
        drop = drop,
        delete_replicasets = delete_replicasets,
    },
}

local function get_session(client)
    checks('stateboard_client')

    if client.session ~= nil
    and client.session:is_alive() then
        return client.session
    end

    local connection = netbox.connect(client.cfg.uri, {
        user = 'client',
        password = client.cfg.password,
        wait_connected = false,
        fetch_schema = false,
    })

    local session = {
        lock_acquired = false,
        call_timeout = client.cfg.call_timeout,
        connection = connection,
        longpoll_ordinal = -1,
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

    local deadline = fiber.clock() + timeout

    while true do
        local session = client:get_session()
        local timeout = deadline - fiber.clock()

        local ret, err = errors.netbox_call(session.connection,
            'longpoll', {timeout, session.longpoll_ordinal},
            {timeout = timeout + client.cfg.call_timeout}
        )

        if ret ~= nil then
            session.longpoll_ordinal = ret.ordinal
            ret.ordinal = nil
            return ret
        end

        if fiber.clock() < deadline then
            fiber.sleep(client.cfg.call_timeout)
            -- continue
        else
            return nil, ClientError:new(err)
        end
    end
end

--- Check that stateboard is available.
--
-- @function check_quorum
-- @treturn boolean true / false
local function check_quorum(client)
    local session = client:get_session()
    return session.connection:ping()
end

local id_str_checked = false
local function set_identification_string(client, new, prev)
    checks('stateboard_client', 'string', '?string')
    if not id_str_checked or prev ~= nil then
        local session = client:get_session()
        local ret, err = errors.netbox_call(session.connection,
            'set_identification_string', {new, prev},
            {timeout = session.call_timeout})
        if ret == nil then
            return nil, SessionError:new(err)
        end
        id_str_checked = true
    end
    return true
end

local client_mt = {
    __type = 'stateboard_client',
    __index = {
        longpoll = longpoll,
        get_session = get_session,
        drop_session = drop_session,
        check_quorum = check_quorum,
        set_identification_string = set_identification_string,
    },
}

local function new(cfg)
    checks({
        uri = 'string',
        password = 'string',
        call_timeout = 'number',
    })

    local client = {
        state_provider = 'tarantool',
        session = nil,
        cfg = table.deepcopy(cfg),
    }
    return setmetatable(client, client_mt)
end

return {
    new = new,
}
