local log = require('log')
local fio = require('fio')
local clock = require('clock')
local fiber = require('fiber')
local checks = require('checks')
local console = require('console')
local argparse = require('cartridge.argparse')

local LOCK_DELAY
local function get_lock_delay()
    return LOCK_DELAY
end

local notification = fiber.cond()
local lock = {
    coordinator = nil,
    session_id = 0,
    session_expiry = 0,
}

local function acquire_lock(uuid, uri)
    checks('string', 'string')

    if box.session.id() ~= lock.session_id
    and box.session.storage.lock_acquired then
        -- lock was stolen while the session was inactive
        return nil, 'The lock was stolen'
    end

    local now = clock.monotonic()

    if box.session.id() ~= lock.session_id
    and box.session.exists(lock.session_id)
    and now < lock.session_expiry then
        -- lock is in another session
        return false
    end

    lock.session_id = box.session.id()
    lock.session_expiry = now + LOCK_DELAY
    box.session.storage.lock_acquired = true

    if lock.coordinator == nil
    or lock.coordinator.uuid ~= uuid
    or lock.coordinator.uri ~= uri
    then
        lock.coordinator = {
            uuid = uuid,
            uri = uri,
        }
        box.space.coordinator_audit:insert({nil, fiber.time(), uuid, uri})
        log.info('Long live the coordinator %q (%s)!', uri, uuid)
    end

    return true
end

local function set_leaders_impl(leaders)
    if type(leaders) ~= 'table' then
        local err = string.format(
            "bad argument to #1 to set_leaders" ..
            " (table expected, got %s)", type(leaders)
        )
        error(err, 2)
    end

    if lock.session_id ~= box.session.id() then
        return nil, 'You are not holding the lock'
    end

    local ordinal = box.sequence.leader_audit:next()
    for _, leader in ipairs(leaders) do
        local replicaset_uuid, instance_uuid = unpack(leader)
        box.space.leader:upsert(
            {replicaset_uuid, instance_uuid}, {{'=', 2, instance_uuid}}
        )
        box.space.leader_audit:insert({
            ordinal, fiber.time(), replicaset_uuid, instance_uuid
        })
    end
    notification:broadcast()
    return true
end

local function set_leaders(...)
    return box.atomic(set_leaders_impl, ...)
end

local function get_leaders()
    local ret = {}
    for _, v in box.space.leader:pairs() do
        ret[v.replicaset_uuid] = v.instance_uuid
    end

    return ret
end

local function longpoll(timeout)
    checks('?number')
    if timeout == nil then
        timeout = 1
    end

    local latest_audit = box.space.leader_audit.index.ordinal:max()
    local latest_ordinal = latest_audit and latest_audit.ordinal or 0
    local session = box.session.storage

    if session.ordinal == nil then
        session.ordinal = latest_ordinal
        return _G.get_leaders()
    elseif session.ordinal > latest_ordinal then
        error('Impossibru! (session_ordinal > latest_ordinal)')
    elseif session.ordinal == latest_ordinal then
        notification:wait(timeout)
    end

    local ret = {}
    for _, v in box.space.leader_audit:pairs({session.ordinal}, {iterator = 'GT'}) do
        ret[v.replicaset_uuid] = v.instance_uuid
        session.ordinal = v.ordinal
    end
    return ret
end

local function get_coordinator()
    if lock ~= nil
    and box.session.exists(lock.session_id)
    and clock.monotonic() < lock.session_expiry then
        return lock.coordinator
    end
end

local function cfg()
    local opts, err = argparse.get_opts({
        listen = 'string',
        workdir = 'string',
        password = 'string',
        lock_delay = 'number',
        console_sock = 'string'
    })

    if err ~= nil then
        error('Configuration error: ' .. tostring(err), 0)
    end

    LOCK_DELAY = opts.lock_delay or 10
    if LOCK_DELAY == nil then
        error("Invalid TARANTOOL_LOCK_DELAY value", 0)
    end

    if opts.workdir == nil then
        error('"workdir" must be specified', 0)
    end

    local ok, err = fio.mktree(opts.workdir)
    if not ok then
        error(err, 0)
    end

    local box_opts, err = argparse.get_box_opts()
    if err ~= nil then
        error('Configuration error: ' .. tostring(err), 0)
    end
    box_opts.work_dir = opts.workdir

    box.cfg(box_opts)

    if opts.console_sock ~= nil then
        local sock = console.listen('unix/:' .. opts.console_sock)
        local unix_port = sock:name().port
        if #unix_port < #opts.console_sock then
            sock:close()
            fio.unlink(unix_port)
            error('Too long console_sock exceeds UNIX_PATH_MAX limit')
        end
    end

    ------------------------------------------------------------------------

    rawset(_G, 'get_lock_delay', get_lock_delay)
    rawset(_G, 'acquire_lock', acquire_lock)
    rawset(_G, 'set_leaders', set_leaders)
    rawset(_G, 'get_leaders', get_leaders)
    rawset(_G, 'longpoll', longpoll)
    rawset(_G, 'get_coordinator', get_coordinator)

    ------------------------------------------------------------------------
    box.schema.user.create('client', { if_not_exists = true })
    box.schema.user.passwd('client', opts.password)

    ------------------------------------------------------------------------
    box.schema.func.create('get_coordinator', { if_not_exists = true })
    box.schema.func.create('get_lock_delay', { if_not_exists = true })
    box.schema.func.create('acquire_lock', { if_not_exists = true })
    box.schema.func.create('set_leaders', { if_not_exists = true })
    box.schema.func.create('get_leaders', { if_not_exists = true })
    box.schema.func.create('longpoll', { if_not_exists = true })

    ------------------------------------------------------------------------
    box.schema.sequence.create('coordinator_audit', {
        if_not_exists = true
    })
    box.schema.space.create('coordinator_audit', {
        format = {
            { name = 'ordinal', type = 'unsigned', is_nullable = false },
            { name = 'time', type = 'number', is_nullable = false },
            { name = 'uuid', type = 'string', is_nullable = false },
            { name = 'uri', type = 'string', is_nullable = false },
        },
        if_not_exists = true,
    })

    box.space.coordinator_audit:create_index('ordinal', {
        unique = true,
        type = 'TREE',
        parts = { { field = 'ordinal', type = 'unsigned' } },
        sequence = 'coordinator_audit',
        if_not_exists = true,
    })

    ------------------------------------------------------------------------
    box.schema.sequence.create('leader_audit', {
        if_not_exists = true
    })
    box.schema.space.create('leader_audit', {
        format = {
            { name = 'ordinal', type = 'unsigned', is_nullable = false },
            { name = 'time', type = 'number', is_nullable = false },
            { name = 'replicaset_uuid', type = 'string', is_nullable = false },
            { name = 'instance_uuid', type = 'string', is_nullable = false },
        },
        if_not_exists = true,
    })

    box.space.leader_audit:create_index('ordinal', {
        unique = true,
        type = 'TREE',
        parts = {
            { field = 'ordinal', type = 'unsigned' },
            { field = 'replicaset_uuid', type = 'string' },
        },
        if_not_exists = true,
    })

    ------------------------------------------------------------------------
    box.schema.space.create('leader', {
        format = {
            { name = 'replicaset_uuid', type = 'string', is_nullable = false },
            { name = 'instance_uuid', type = 'string', is_nullable = false },
        },
        if_not_exists = true,
    })

    box.space.leader:create_index('replicaset_uuid', {
        unique = true,
        type = 'TREE',
        parts = { { field = 'replicaset_uuid', type = 'string' } },
        if_not_exists = true,
    })

    ------------------------------------------------------------------------

    box.schema.user.grant('client', 'read,write', 'space', 'coordinator_audit', { if_not_exists = true })
    box.schema.user.grant('client', 'read,write', 'space', 'leader_audit', { if_not_exists = true })
    box.schema.user.grant('client', 'read,write', 'space', 'leader', { if_not_exists = true })
    box.schema.user.grant('client', 'read,write', 'sequence', 'coordinator_audit', { if_not_exists = true })
    box.schema.user.grant('client', 'read,write', 'sequence', 'leader_audit', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'get_coordinator', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'get_lock_delay', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'acquire_lock', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'set_leaders', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'get_leaders', { if_not_exists = true })
    box.schema.user.grant('client', 'execute', 'function', 'longpoll', { if_not_exists = true })

    -- Enable listen port only after all spaces are set up
    box.cfg({ listen = opts.listen })

    ------------------------------------------------------------------------

    fiber.new(function()
        fiber.self():name('audit-log')
        -- It's not good to print logs inside a transaction
        -- thus logging is performed in the separate fiber
        _G.longpoll(0)

        while true do
            for replicaset_uuid, instance_uuid in pairs(_G.longpoll(10)) do
                log.info('New leader %s -> %s', replicaset_uuid, instance_uuid)
            end
        end
    end)
end

return {
    cfg = cfg,
}
