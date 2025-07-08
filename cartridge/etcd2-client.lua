local json = require('json')
local etcd2 = require('cartridge.etcd2')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local log = require('log')

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
        local replicaset_uuid = leader[1]
        local instance_uuid = leader[2]
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

local function delete_replicasets(session, replicasets)
    checks('etcd2_session', 'table')

    if not session:is_locked() then
        return nil, SessionError:new('You are not holding the lock')
    end

    if not session:is_alive() then
        return nil, SessionError:new('Session is dropped')
    end

    assert(session.leaders ~= nil)
    assert(session.leaders_index ~= nil)

    local new_leaders = table.copy(session.leaders)

    for _, replicaset_uuid in ipairs(replicasets) do
        if new_leaders[replicaset_uuid] == nil then
            new_leaders[replicaset_uuid] = nil
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
    for _, replicaset_uuid in ipairs(replicasets) do
        session.connection:request('DELETE', '/vclockkeeper/'..replicaset_uuid)
    end

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

local function set_vclockkeeper(session, replicaset_uuid, instance_uuid, vclock, skip_error_on_change)
    checks('etcd2_session', 'string', 'string', '?table', '?boolean')
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

    -- for testing purpose only:
    if rawget(_G, 'test_etcd2_client_ordinal_errnj') == true then
        fiber.sleep(1)
    end

    local vclockkeeper = json.encode({
        instance_uuid = instance_uuid,
        vclock = vclock and setmetatable(vclock, {_serialize = 'sequence'}),
    })

    request_args.value = vclockkeeper

    local resp, err = session.connection:request('PUT',
        '/vclockkeeper/'.. replicaset_uuid, request_args)

    if resp == nil then
        if err.etcd_code == etcd2.EcodeTestFailed then
            err.err = ('Vclockkeeper changed between calls - %s'):format(err.err)
            if skip_error_on_change == true then
                log.error(err.err)
                return true
            end
        end

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
        delete_replicasets = delete_replicasets,
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
        -- longpoll_index is the latest index received from etcd.
        if session.longpoll_index == nil then
            resp, err = session.connection:request('GET', '/leaders')
            -- After a simple GET we can be sure that the response
            -- represents the newest information at a given x-etcd-index
            if resp ~= nil then
                session.longpoll_index = assert(resp.etcd_index)
            elseif err.etcd_code == etcd2.EcodeKeyNotFound then
                session.longpoll_index = assert(err.etcd_index)
            end
        else
            resp, err = session.connection:request('GET', '/leaders', {
                wait = true,
                waitIndex = session.longpoll_index + 1,
            }, {timeout = timeout})
            -- A GET with the waitIndex specified will return the next
            -- modifiedIndex (if it exists), but there may exist the
            -- newer one.
            if resp ~= nil then
                session.longpoll_index = assert(resp.node.modifiedIndex)
            elseif err.etcd_code == etcd2.EcodeEventIndexCleared then
                -- The event in requested index is outdated and cleared
                -- Proceed with a simple GET without waitIndex.
                session.longpoll_index = nil
            end
        end

        if resp ~= nil then
            return json.decode(resp.node.value)
        end

        if fiber.clock() < deadline then
            -- In case of any error keep retrying till the deadline.
            fiber.sleep(session.connection.request_timeout)
        elseif err.http_code == 408 then
            -- Timeout with headers means that there're no events
            -- between requested waitIndex and X-Etcd-Index in response.
            -- Therefore one should bump longpoll_index.
            if err.etcd_index then
                session.longpoll_index = err.etcd_index
            end
            return {}
        else
            return nil, ClientError:new(err)
        end
    end
end

--- Check that etcd cluster has a quorum.
--
-- @function check_quorum
-- @treturn[1] boolean true
-- @treturn[2] false
-- @treturn[2] table Error description
local function check_quorum(client)
    local session = client:get_session()
    local resp, err = session.connection:request('GET', '/lock', {quorum=true})
    if resp ~= nil then
        return true
    elseif err.etcd_code == etcd2.EcodeKeyNotFound then
        return true
    end

    return false, err
end


local id_str_checked = false
local function set_identification_string(client, new, prev)
    checks('etcd2_client', 'string', '?string')
    local session = client:get_session()

    if not id_str_checked and prev == nil then
        local resp, err = session.connection:request('GET', '/identification_str')

        if resp and resp.node.value == new then
            id_str_checked = true
            return true
        elseif err and err.etcd_code ~= etcd2.EcodeKeyNotFound then
            return nil, SessionError:new(err)
        end

        local resp, err = session.connection:request('PUT', '/identification_str', {
            prevExist = false, value = new,
        })

        if resp == nil then
            if err.etcd_code == etcd2.EcodeNodeExist then
                local resp, get_err = session.connection:request('GET', '/identification_str')
                if resp and resp.node.value == new then
                    id_str_checked = true
                    return true
                elseif resp then
                    err.err = ('Prefix %s already used by another Cartridge cluster'):format(client.cfg.prefix)
                else
                    err = get_err
                end
            end
            return nil, SessionError:new(err)
        end
        id_str_checked = true
    else
        local resp, err = session.connection:request('PUT', '/identification_str', {
            prevValue = prev, value = new,
        })
        if resp == nil then
            if err.etcd_code == etcd2.EcodeTestFailed then
                err.err = ('Identification string changed between calls'):format(err.err)
            end
            return nil, SessionError:new(err)
        end
    end
    return true
end

local client_mt = {
    __type = 'etcd2_client',
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
