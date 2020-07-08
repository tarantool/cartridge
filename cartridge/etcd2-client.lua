local json = require('json')
local etcd2 = require('cartridge.etcd2')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')

local ClientError  = errors.new_class('ClientError')
local SessionError = errors.new_class('SessionError')

local function acquire_lock(session, lock_args)
    checks('etcd2_session', {
        uuid = 'string',
        uri = 'string',
    })

    if not session:is_alive() then
        return nil, SessionError:new('Session is dead')
    end

    local request_args = {
        value = json.encode(lock_args),
        ttl = session.lock_delay,
    }

    if session:is_locked() then
        assert(session.lock_index > 0)
        request_args.prevIndex = session.lock_index
    else
        request_args.prevExist = false
    end

    local resp, err = session.connection:request('PUT', '/lock',
        request_args
    )
    if resp == nil then
        if err.etcd_code == etcd2.EcodeNodeExist then
            return false
        else
            session.connection:close()
            if err.etcd_code == etcd2.EcodeTestFailed
            or err.etcd_code == etcd2.EcodeKeyNotFound then
                return nil, SessionError:new('The lock was stolen')
            end
            return nil, err
        end
    end

    local lock_index = resp.node.modifiedIndex

    -- if session is already locked there is no need to renew leaders
    if session:is_locked() then
        assert(session.leaders ~= nil)
        assert(session.leaders_index ~= nil)
        session.lock_index = lock_index
        return true
    end

    local leaders_value
    local resp, err = session.connection:request('GET', '/leaders')
    if resp ~= nil then
        leaders_value = resp.node.value
    elseif err.etcd_code == etcd2.EcodeKeyNotFound then
        leaders_value = '{}'
    else
        return nil, err
    end

    local resp, err = session.connection:request('PUT', '/leaders',
        {value = leaders_value}
    )
    if resp == nil then
        return nil, err
    end

    session.leaders = json.decode(resp.node.value)
    session.leaders_index = resp.node.modifiedIndex
    session.lock_index = lock_index
    return true
end

local function get_lock_delay(session)
    checks('etcd2_session')
    return session.lock_delay
end

local function set_leaders(session, updates)
    checks('etcd2_session', 'table')

    if not session:is_locked() then
        return nil, SessionError:new('You are not holding the lock')
    end

    if not session:is_alive() then
        return nil, SessionError:new('Session is dropped')
    end

    assert(session.leaders ~= nil)
    assert(session.leaders_index ~= nil)

    local old_leaders = session.leaders
    local new_leaders = {}
    for _, leader in ipairs(updates) do
        local replicaset_uuid, instance_uuid = unpack(leader)
        if new_leaders[replicaset_uuid] ~= nil then
            return nil, SessionError:new('Duplicate key in updates')
        end

        new_leaders[replicaset_uuid] = instance_uuid
    end

    for replicaset_uuid, instance_uuid in pairs(old_leaders) do
        if new_leaders[replicaset_uuid] == nil then
            new_leaders[replicaset_uuid] = instance_uuid
        end
    end

    if session._set_leaders_mutex == nil then
        session._set_leaders_mutex = fiber.channel(1)
    end
    session._set_leaders_mutex:put(box.NULL)

    local resp, err = SessionError:pcall(function()
        return session.connection:request('PUT', '/leaders', {
            value = json.encode(new_leaders),
            prevIndex = session.leaders_index,
        })
    end)

    session._set_leaders_mutex:get()

    if resp == nil then
        return nil, err
    end

    session.leaders = new_leaders
    session.leaders_index = resp.node.modifiedIndex

    return true
end

local function get_leaders(session)
    checks('etcd2_session')

    if session:is_locked() then
        return session.leaders
    elseif not session:is_alive() then
        return nil, SessionError:new('Session is dropped')
    end

    local resp, err = session.connection:request('GET', '/leaders')
    if resp ~= nil then
        return json.decode(resp.node.value)
    elseif err.etcd_code == etcd2.EcodeKeyNotFound then
        return {}
    else
        return nil, err
    end
end

local function get_coordinator(session)
    checks('etcd2_session')

    if not session:is_alive() then
        return nil
    end

    local resp, err = session.connection:request('GET', '/lock')

    if resp ~= nil then
        return json.decode(resp.node.value)
    elseif err.etcd_code == etcd2.EcodeKeyNotFound then
        -- there is no coordinator
        return nil
    else
        return nil, err
    end
end

local function set_vclockkeeper(session, replicaset_uuid, instance_uuid, vclock)
    checks('etcd2_session', 'string', 'string', '?table')
    assert(session.connection ~= nil)
    local request_args = {}

    local resp, err = session.connection:request('GET',
        '/vclockkeeper/'..replicaset_uuid)

    if err ~= nil then
        if err.etcd_code == etcd2.EcodeKeyNotFound then
            request_args.prevExist = false
            goto set_vclockkeeper
        else
            return nil, SessionError:new(err)
        end
    end

    do
        local keeper = json.decode(resp.node.value)
        if keeper.instance_uuid == instance_uuid and
        vclock == nil then
            -- No update needed
            return true
        end
    end

    request_args.prevIndex = resp.node.modifiedIndex

    ::set_vclockkeeper::
    -- there must be no interventions between get_vclockkeeper and
    -- set_vclockkeeper during consistent switchover

    local vclockkeeper = json.encode({
        instance_uuid = instance_uuid,
        vclock = vclock and setmetatable(vclock, {_serialize = 'sequence'}),
    })

    request_args.value = vclockkeeper

    local resp, err = session.connection:request('PUT',
        '/vclockkeeper/'.. replicaset_uuid, request_args)

    if resp == nil then
        return nil, SessionError:new(err)
    end

    session.vclockkeeper_index = nil
    session.replicaset_uuid = nil
    return true
end

local function get_vclockkeeper(session, replicaset_uuid)
    checks('etcd2_session', 'string')
    assert(session.connection ~= nil)

    local resp, err = session.connection:request('GET',
        '/vclockkeeper/'..replicaset_uuid)

    if err ~= nil then
        if err.etcd_code == etcd2.EcodeKeyNotFound then
            return nil
        else
            return SessionError:new(err)
        end
    end

    local vclockkeeper = json.decode(resp.node.value)
    vclockkeeper.replicaset_uuid = replicaset_uuid

    -- vclockkeeper_index will be checked in set_vclockkeeper
    session.vclockkeeper_index = resp.node.modifiedIndex
    session.vclockkeeper_replicaset = replicaset_uuid

    return vclockkeeper
end

local function is_locked(session)
    checks('etcd2_session')
    return session.connection:is_connected()
        and session.lock_index ~= nil
end

local function is_alive(session)
    checks('etcd2_session')
    return session.connection.state ~= 'closed'
end

local function drop(session)
    checks('etcd2_session')
    assert(session.connection ~= nil)

    -- save lock_index locally before request yields
    local lock_index = session.lock_index
    session.lock_index = nil
    if lock_index ~= nil then
        pcall(function()
            session.connection:request('DELETE', '/lock', {
                prevIndex = lock_index,
            })
        end)
    end

    session.connection:close()
    return true
end

local session_mt = {
    __type = 'etcd2_session',
    __index = {
        is_alive = is_alive,
        is_locked = is_locked,
        acquire_lock = acquire_lock,
        set_leaders = set_leaders,
        get_leaders = get_leaders,
        get_lock_delay = get_lock_delay,
        get_coordinator = get_coordinator,
        set_vclockkeeper = set_vclockkeeper,
        get_vclockkeeper = get_vclockkeeper,
        drop = drop,
    },
}

local function get_session(client)
    checks('etcd2_client')

    if client.session ~= nil
    and client.session:is_alive() then
        return client.session
    end

    local connection = etcd2.connect(client.cfg.endpoints, {
        prefix = client.cfg.prefix,
        request_timeout = client.cfg.request_timeout,
        username = client.cfg.username,
        password = client.cfg.password,
    })

    local session = {
        connection = connection,
        lock_delay = client.cfg.lock_delay,

        lock_index = nil, -- used by session:acquire_lock() and :drop()
        leaders_index = nil, -- used by session:set_leaders() and :acquire_lock()
        longpoll_index = nil, -- used by client:longpoll()
    }
    client.session = setmetatable(session, session_mt)
    return client.session
end

local function drop_session(client)
    checks('etcd2_client')
    if client.session ~= nil then
        client.session:drop()
        client.session = nil
    end
end

local function longpoll(client, timeout)
    checks('etcd2_client', 'number')

    local deadline = fiber.clock() + timeout

    while true do
        local session = client:get_session()
        local timeout = deadline - fiber.clock()

        local resp, err
        if session.longpoll_index == nil then
            resp, err = session.connection:request('GET', '/leaders')
            if resp == nil and err.etcd_code == etcd2.EcodeKeyNotFound then
                session.longpoll_index = err.etcd_index
            end
        else
            resp, err = session.connection:request('GET', '/leaders', {
                wait = true,
                waitIndex = session.longpoll_index + 1,
            }, {timeout = timeout})
        end

        if resp ~= nil then
            session.longpoll_index = resp.node.modifiedIndex
            return json.decode(resp.node.value)
        end

        if fiber.clock() < deadline then
            -- connection refused etc.
            fiber.sleep(session.connection.request_timeout)
        elseif err.http_code == 408 then
            -- timeout, no updates
            return {}
        else
            return nil, ClientError:new(err)
        end
    end
end

local client_mt = {
    __type = 'etcd2_client',
    __index = {
        longpoll = longpoll,
        get_session = get_session,
        drop_session = drop_session,
    },
}

local function new(cfg)
    checks({
        prefix = 'string',
        lock_delay = 'number',
        endpoints = 'table',
        username = 'string',
        password = 'string',
        request_timeout = 'number',
    })

    local client = {
        state_provider = 'etcd2',
        session = nil,
        cfg = table.deepcopy(cfg),
    }

    return setmetatable(client, client_mt)
end

return {
    new = new,
}
