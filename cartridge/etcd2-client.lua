local json = require('json')
local etcd2 = require('cartridge.etcd2')
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')

local ClientError  = errors.new_class('ClientError')
local SessionError = errors.new_class('SessionError')

local function decode_state(value)
    local state = json.decode(value)
    if state.version ~= nil and state.version ~= 1 then
        return nil, SessionError:new('Unsupported failover state version %s', state.version)
    end
    return state
end

local function read_state(session)
    local resp, err = session.connection:request('GET', '/leaders')
    if resp == nil then
        if err.etcd_code == etcd2.EcodeKeyNotFound then
            return {}, nil, 0
        end
        return nil, err
    end

    local state, err = decode_state(resp.node.value)
    return state, err, resp.node.modifiedIndex
end

local function update_state(session, update, ...)
    local deadline = fiber.clock() + session.connection.request_timeout
    local write_err
    repeat
        local state, err, index = read_state(session)
        if state == nil then
            return nil, err
        end

        local state, err = update(session, state, index, ...)
        if state == nil then
            return nil, err
        end

        local args = index == 0 and {prevExist = false} or {prevIndex = index}
        args.value = json.encode(state)
        local resp
        resp, write_err = session.connection:request('PUT', '/leaders', args)
        if resp ~= nil then
            return true
        end
    until (write_err.etcd_code ~= etcd2.EcodeTestFailed and
           write_err.etcd_code ~= etcd2.EcodeNodeExist) or fiber.clock() >= deadline
    return nil, write_err
end

local function check_lock(session)
    if not session:is_locked() then
        return nil, SessionError:new('You are not holding the lock')
    end

    local resp, err = session.connection:request('GET', '/lock')
    if resp == nil and err.etcd_code ~= etcd2.EcodeKeyNotFound then
        return nil, err
    end
    if resp == nil or resp.node.createdIndex ~= session.lock_epoch then
        return nil, SessionError:new('You are not holding the lock')
    end
    return true
end

local function migrate_state(session, leaders, index)
    local replicasets = {}
    for replicaset_uuid, instance_uuid in pairs(leaders) do
        replicasets[replicaset_uuid] = {instance_uuid = instance_uuid, revision = index}
    end

    local resp, err = session.connection:request('GET', '/vclockkeeper')
    if resp == nil and err.etcd_code ~= etcd2.EcodeKeyNotFound then
        return nil, err
    end
    for _, node in ipairs(resp and resp.node.nodes or {}) do
        if not node.dir then
            local replicaset_uuid = node.key:match('[^/]+$')
            local replicaset = replicasets[replicaset_uuid] or {}
            local keeper = json.decode(node.value)
            keeper.revision = node.modifiedIndex
            replicaset.vclockkeeper = keeper
            replicasets[replicaset_uuid] = replicaset
        end
    end
    return {version = 1, replicasets = replicasets}
end

local function claim_state(session, state, index)
    if state.version == nil then
        local err
        state, err = migrate_state(session, state, index)
        if state == nil then
            return nil, err
        end
    end

    local ok, err = check_lock(session)
    if ok == nil then
        return nil, err
    elseif state.coordinator ~= nil and state.coordinator >= session.lock_epoch then
        return nil, SessionError:new('The lock was stolen')
    end
    state.coordinator = session.lock_epoch
    return state
end

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
    local renewing = session.lock_index ~= nil
    if renewing then
        request_args.prevIndex = session.lock_index
    else
        request_args.prevExist = false
    end

    local resp, err = session.connection:request('PUT', '/lock', request_args)
    if resp == nil then
        if err.etcd_code == etcd2.EcodeNodeExist then
            return false
        end
        session.connection:close()
        if err.etcd_code == etcd2.EcodeTestFailed
        or err.etcd_code == etcd2.EcodeKeyNotFound then
            return nil, SessionError:new('The lock was stolen')
        end
        return nil, err
    end

    session.lock_index = resp.node.modifiedIndex
    if renewing then
        return true
    end

    -- A new epoch fences writes prepared by the previous coordinator.
    session.lock_epoch = resp.node.createdIndex
    local ok, err = update_state(session, claim_state)
    if ok == nil then
        session:drop()
        return nil, err
    end
    return true
end

local function get_lock_delay(session)
    checks('etcd2_session')
    return session.lock_delay
end

local function check_owner(session, state)
    if state.coordinator ~= session.lock_epoch then
        return nil, SessionError:new('You are not holding the lock')
    end
    return check_lock(session)
end

local function set_leaders_impl(session, state, index, leaders, force)
    local ok, err = check_owner(session, state)
    if ok == nil then
        return nil, err
    end

    local seen = {}
    for _, leader in ipairs(leaders) do
        local replicaset_uuid, instance_uuid = unpack(leader)
        if seen[replicaset_uuid] then
            return nil, SessionError:new('Duplicate key in updates')
        end
        seen[replicaset_uuid] = true

        local replicaset = state.replicasets[replicaset_uuid] or {}
        replicaset.instance_uuid = instance_uuid
        replicaset.revision = index + 1
        local keeper = replicaset.vclockkeeper
        if force and (keeper == nil or keeper.instance_uuid ~= instance_uuid) then
            replicaset.vclockkeeper = {instance_uuid = instance_uuid, revision = index + 1}
        end
        state.replicasets[replicaset_uuid] = replicaset
    end
    return state
end

local function set_leaders(session, updates, force)
    checks('etcd2_session', 'table', '?boolean')
    if not session:is_locked() then
        return nil, SessionError:new('You are not holding the lock')
    end
    return update_state(session, set_leaders_impl, updates, force)
end

local function delete_replicasets_impl(session, state, _, replicasets)
    local ok, err = check_owner(session, state)
    if ok == nil then
        return nil, err
    end

    for _, replicaset_uuid in ipairs(replicasets) do
        state.replicasets[replicaset_uuid] = nil
    end
    return state
end

local function delete_replicasets(session, replicasets)
    checks('etcd2_session', 'table')
    if not session:is_locked() then
        return nil, SessionError:new('You are not holding the lock')
    end
    return update_state(session, delete_replicasets_impl, replicasets)
end

local function collect_leaders(state)
    if state.version == nil then
        return state
    end

    local leaders = {}
    for replicaset_uuid, replicaset in pairs(state.replicasets) do
        leaders[replicaset_uuid] = replicaset.instance_uuid
    end
    return leaders
end

local function get_leaders(session)
    checks('etcd2_session')
    if not session:is_alive() then
        return nil, SessionError:new('Session is dropped')
    end

    local state, err = read_state(session)
    if state == nil then
        return nil, err
    end
    return collect_leaders(state)
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

local function get_vclockkeepers(session)
    checks('etcd2_session')
    local state, err = read_state(session)
    if state == nil then
        return nil, err
    end

    local keepers = {}
    for replicaset_uuid, replicaset in pairs(state.replicasets) do
        if replicaset.vclockkeeper ~= nil then
            keepers[replicaset_uuid] = replicaset.vclockkeeper.instance_uuid
        end
    end
    return keepers
end

local function get_appointment(session, replicaset_uuid)
    checks('etcd2_session', 'string')
    local state, err = read_state(session)
    if state == nil then
        return nil, err
    elseif state.version == nil then
        return nil
    end

    local replicaset = state.replicasets[replicaset_uuid]
    if replicaset == nil or replicaset.instance_uuid == nil then
        return nil
    end

    local keeper = replicaset.vclockkeeper
    return {
        instance_uuid = replicaset.instance_uuid,
        revision = replicaset.revision,
        vclockkeeper = keeper,
        keeper_revision = keeper and keeper.revision or 0,
    }
end

local function get_vclockkeeper(session, replicaset_uuid)
    checks('etcd2_session', 'string')
    local state, err = read_state(session)
    if state == nil then
        return nil, SessionError:new(err)
    end

    local replicaset = state.replicasets and state.replicasets[replicaset_uuid]
    local keeper = replicaset and replicaset.vclockkeeper
    if keeper == nil then
        return nil, nil, 0
    end
    return {
        replicaset_uuid = replicaset_uuid,
        instance_uuid = keeper.instance_uuid,
        vclock = keeper.vclock,
    }, nil, keeper.revision
end

local function store_vclockkeeper(state, index, replicaset_uuid, instance_uuid, vclock)
    setmetatable(vclock, {_serialize = 'sequence'})
    local replicaset = state.replicasets[replicaset_uuid] or {}
    replicaset.vclockkeeper = {
        instance_uuid = instance_uuid,
        revision = index + 1,
        vclock = vclock,
    }
    state.replicasets[replicaset_uuid] = replicaset
    return state
end

local function recover_vclockkeeper(session, state, index, replicaset_uuid, instance_uuid, vclock)
    if state.coordinator ~= nil or (state.version == nil and index ~= 0) then
        return nil, SessionError:new('Appointment changed')
    elseif state.version == nil then
        local err
        state, err = migrate_state(session, state, index)
        if state == nil then
            return nil, err
        end
    end

    local replicaset = state.replicasets[replicaset_uuid]
    local keeper = replicaset and replicaset.vclockkeeper
    if keeper ~= nil and keeper.instance_uuid ~= instance_uuid then
        return nil, SessionError:new('Vclockkeeper changed between calls')
    end
    return store_vclockkeeper(state, index, replicaset_uuid, instance_uuid, vclock)
end

local function activate_impl(session, state, index, replicaset_uuid, instance_uuid, appointment, vclock)
    if appointment == nil then
        return recover_vclockkeeper(session, state, index, replicaset_uuid, instance_uuid, vclock)
    end

    local replicaset = state.replicasets and state.replicasets[replicaset_uuid]
    if replicaset == nil
    or replicaset.instance_uuid ~= instance_uuid
    or replicaset.revision ~= appointment.revision
    then
        return nil, SessionError:new('Appointment changed')
    end

    local keeper = replicaset.vclockkeeper
    local keeper_revision = keeper and keeper.revision or 0
    if keeper_revision ~= appointment.keeper_revision then
        return nil, SessionError:new('Vclockkeeper changed between calls')
    end
    return store_vclockkeeper(state, index, replicaset_uuid, instance_uuid, vclock)
end

local function activate(session, replicaset_uuid, instance_uuid, appointment, vclock)
    checks('etcd2_session', 'string', 'string', '?table', 'table')
    return update_state(session, activate_impl, replicaset_uuid, instance_uuid, appointment, vclock)
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
    session.lock_epoch = nil
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
        get_vclockkeeper = get_vclockkeeper,
        get_vclockkeepers = get_vclockkeepers,
        get_appointment = get_appointment,
        activate = activate,
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

        lock_index = nil,
        lock_epoch = nil,
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
            local state, err = decode_state(resp.node.value)
            if state == nil then
                return nil, err
            end
            return collect_leaders(state)
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
