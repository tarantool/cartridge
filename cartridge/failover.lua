--- Gather information regarding instances leadership.
--
-- Failover can operate in two modes:
--
-- * In `disabled` mode the leader is the first server configured in
--   `topology.replicasets[].master` array.
-- * In `eventual` mode the leader isn't elected consistently.
--   Instead, every instance in cluster thinks the leader is the
--   first **healthy** server in replicaset, while instance health is
--   determined according to membership status (the SWIM protocol).
-- * In `stateful` mode leaders appointments are polled from the
--   external storage. (**Added** in v2.0.2-2)
--
-- This module behavior depends on the instance state.
--
-- From the very beginning it reports `is_rw() == false`,
-- `is_leader() == false`, `get_active_leaders() == {}`.
--
-- The module is configured when the instance enters `ConfiguringRoles`
-- state for the first time. From that moment it reports actual values
-- according to the mode set in clusterwide config.
--
-- (**Added** in v1.2.0-17)
--
-- @module cartridge.failover
-- @local

local log = require('log')
local json = require('json')
local fiber = require('fiber')
local clock = require('clock')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.failover')
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')
local cluster_cookie = require('cartridge.cluster-cookie')
local stateboard_client = require('cartridge.stateboard-client')
local etcd2_client = require('cartridge.etcd2-client')
local raft_failover = require('cartridge.failover.raft')
local leader_autoreturn = require('cartridge.failover.leader_autoreturn')
local argparse = require('cartridge.argparse')

local FailoverError = errors.new_class('FailoverError')
local SwitchoverError = errors.new_class('SwitchoverError')
local ApplyConfigError = errors.new_class('ApplyConfigError')
local ValidateConfigError = errors.new_class('ValidateConfigError')
local StateProviderError = errors.new_class('StateProviderError')
local SetOptionsError = errors.new_class('SetOptionsError')

vars:new('mode')
vars:new('all_roles')
vars:new('instance_uuid')
vars:new('replicaset_uuid')
vars:new('membership_notification', membership.subscribe())
vars:new('consistency_needed', false)
vars:new('clusterwide_config')
vars:new('failover_fiber')
vars:new('failover_err')
vars:new('cookie_check_err', nil)
vars:new('enable_synchro_mode', false)
vars:new('disable_raft_on_small_clusters', true)
vars:new('schedule', {})
vars:new('client')
vars:new('cache', {
    active_leaders = {--[[ [replicaset_uuid] = leader_uuid ]]},
    is_vclockkeeper = false,
    is_leader = false,
    is_rw = false,
})
vars:new('fencing_fiber')
do
    local defaults = topology.get_failover_params()
    vars:new('fencing_enabled', defaults.fencing_enabled)
    vars:new('fencing_timeout', defaults.fencing_timeout)
    vars:new('fencing_pause', defaults.fencing_pause)
end
vars:new('options', {
    WAITLSN_PAUSE = 0.2,
    WAITLSN_TIMEOUT = 3, -- One may treat it as WAIT_CONSISTENCY_TIMEOUT
    LONGPOLL_TIMEOUT = 30,
    NETBOX_CALL_TIMEOUT = 1,
})
vars:new('failover_paused', false)

-- suppressing vars
vars:new('failover_suppressed', false)
vars:new('failover_trigger_cnt', 0)
vars:new('suppress_threshold', math.huge)
vars:new('suppress_timeout', math.huge)
vars:new('suppress_fiber', nil)


function _G.__cartridge_failover_get_lsn(timeout)
    box.ctl.wait_ro(timeout)
    local box_info = box.info
    return {
        id  = box_info.id,
        lsn = box_info.lsn,
    }
end

function _G.__cartridge_failover_wait_rw(timeout)
    return errors.pcall('WaitRwError', box.ctl.wait_rw, timeout)
end

function _G.__cartridge_failover_pause()
    vars.failover_paused = true
end

function _G.__cartridge_failover_resume()
    vars.failover_paused = false
end

local reconfigure_all -- function implemented below

--- Cancel all pending reconfigure_all tasks.
-- @function schedule_clear
-- @local
local function schedule_clear()
    for id, task in pairs(vars.schedule) do
        if task:status() == 'dead' then
            vars.schedule[id] = nil
        elseif not task.storage.is_busy then
            vars.schedule[id] = nil
            task:cancel()
        -- else
            -- preserve busy tasks
        end
    end
end

--- Schedule new reconfigure_all task.
-- @function schedule_add
-- @local
local function schedule_add()
    schedule_clear()
    local task = fiber.new(reconfigure_all, vars.cache.active_leaders)
    local id = task:id()
    task:name('cartridge.failover.task')
    vars.schedule[id] = task
    return id
end

--- Generate appointments according to clusterwide configuration.
-- Used in 'disabled' failover mode.
-- @function _get_appointments_disabled_mode
-- @local
local function _get_appointments_disabled_mode(topology_cfg)
    checks('table')
    local replicasets = assert(topology_cfg.replicasets)

    local appointments = {}

    for replicaset_uuid, _ in pairs(replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid, nil, {only_enabled = true}
        )
        appointments[replicaset_uuid] = leaders[1]
    end

    return appointments
end

--- Generate appointments according to membership status.
-- Used in 'eventual' failover mode.
-- @function _get_appointments_eventual_mode
-- @local
local function _get_appointments_eventual_mode(topology_cfg)
    checks('table')
    local replicasets = assert(topology_cfg.replicasets)

    local appointments = {}

    for replicaset_uuid, _ in pairs(replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid, nil, {only_enabled = true}
        )

        for _, instance_uuid in ipairs(leaders) do
            local server = topology_cfg.servers[instance_uuid]
            local member = membership.get_member(server.uri)

            if member ~= nil
            and (member.status == 'alive' or member.status == 'suspect')
            and member.payload.uuid == instance_uuid
            and (
                member.payload.state == 'ConfiguringRoles' or
                member.payload.state == 'RolesConfigured'
            ) then
                appointments[replicaset_uuid] = instance_uuid
                break
            end
        end

        if appointments[replicaset_uuid] == nil then
            appointments[replicaset_uuid] = leaders[1]
        end
    end

    return appointments
end

--- Get appointments from external storage.
-- Used in 'stateful' failover mode.
-- @function _get_appointments_stateful_mode
-- @local
local function _get_appointments_stateful_mode(client, timeout)
    checks('stateboard_client|etcd2_client', 'number')
    return client:longpoll(timeout)
end

local function describe(uuid)
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    local servers = assert(topology_cfg.servers)

    if uuid == vars.instance_uuid then
        return string.format('%s (me)', uuid)
    elseif servers[uuid] ~= nil then
        return string.format('%s (%q)', uuid, servers[uuid].uri)
    else
        return uuid
    end
end

--- Accept new appointments.
--
-- Get appointments wherever they come from and put them into cache.
-- Cached active_leaders table is never modified, but overriden by it's
-- modified copy (if necessary).
--
-- @function accept_appointments
-- @local
-- @tparam {[string]=string} replicaset_uuid to leader_uuid map
-- @treturn boolean Whether leadership map has changed
local function accept_appointments(appointments)
    checks('table')
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    local replicasets = assert(topology_cfg.replicasets)

    local active_leaders = table.copy(vars.cache.active_leaders)

    -- Merge new appointments
    for replicaset_uuid, leader_uuid in pairs(appointments) do
        active_leaders[replicaset_uuid] = leader_uuid
    end

    -- Remove replicasets that aren't listed in topology
    for replicaset_uuid, _ in pairs(active_leaders) do
        if replicasets[replicaset_uuid] == nil then
            active_leaders[replicaset_uuid] = nil
        end
    end

    local changed = false

    for replicaset_uuid, leader_uuid in pairs(active_leaders) do
        local current_leader = vars.cache.active_leaders[replicaset_uuid]
        if current_leader == leader_uuid then
            goto continue
        end

        changed = true

        log.info('Replicaset %s%s: new leader %s, was %s',
            replicaset_uuid,
            replicaset_uuid == vars.replicaset_uuid and ' (me)' or '',
            describe(leader_uuid),
            describe(current_leader)
        )

        ::continue::
    end

    if changed then
        vars.cache.active_leaders = active_leaders
        membership.set_payload('leader_uuid', active_leaders[vars.replicaset_uuid])
    end

    return changed
end

local function apply_config(mod)
    checks('?table')
    if mod == nil then
        return true
    end

    if type(mod.apply_config) ~= 'function' then
        return true
    end

    local conf = vars.clusterwide_config:get_readonly()
    if type(mod.validate_config) == 'function' then
        local ok, err = ValidateConfigError:pcall(
            mod.validate_config, conf, conf
        )
        if not ok then
            err = err or ValidateConfigError:new(
                'validate_config() returned %s', ok
            )
            return nil, err
        end
    end

    return ApplyConfigError:pcall(
        mod.apply_config, conf, {is_master = vars.cache.is_leader}
    )
end


local function on_apply_config(mod, state)
    checks('?table', 'string')
    if mod == nil then
        return true
    end

    local conf = vars.clusterwide_config:get_readonly()

    if type(mod.on_apply_config) == 'function' then
        local ok, err = ApplyConfigError:pcall(mod.on_apply_config, conf, state)
        if not ok then
            log.error('Role %q on_apply_config in failover failed: %s', mod.role_name, err and err.err or err)
        end
    end
end

--- Perform the fencing healthcheck.
--
-- Fencing is actuated when the instance disconnects from both
-- the state provider and a replica, i.e. the check returns false.
--
-- @function fencing_check
-- @local
-- @treturn boolean true / false
local function fencing_healthcheck()
    -- If state provider is available then
    -- there is no need to actuate fencing yet
    if assert(vars.client):check_quorum() then
        return true
    end

    local topology_cfg = vars.clusterwide_config:get_readonly('topology')

    -- Otherwise check connectivity with replicas
    local leaders_order = topology.get_leaders_order(
        topology_cfg, vars.replicaset_uuid, nil, {only_enabled = true}
    )
    for _, instance_uuid in ipairs(leaders_order) do
        local server = assert(topology_cfg.servers[instance_uuid])

        local member = membership.get_member(server.uri)

        if member ~= nil
        and (member.status == 'alive')
        and (member.payload.uuid == instance_uuid)
        then
            goto continue
        end

        log.warn(
            'State provider lacks the quorum' ..
            ' and replica (%s) is unavailable', server.uri
        )
        do return false end

        ::continue::
    end

    return true
end

local function fencing_watch()
    log.info(
        'Fencing enabled (step %s, timeout %s)',
        vars.fencing_pause, vars.fencing_timeout
    )

    if not (vars.fencing_timeout >= vars.fencing_pause) then
        log.warn('Fencing timeout should be >= pause')
    end

    local deadline = fiber.clock() + vars.fencing_timeout
    repeat
        fiber.sleep(vars.fencing_pause)

        if fencing_healthcheck() then
            -- postpone the fencing actuation
            deadline = fiber.clock() + vars.fencing_timeout
        end
    until fiber.clock() > deadline

    if not accept_appointments({[vars.replicaset_uuid] = box.NULL}) then
        log.error('Assertion failed. Was fencing actuated twice?')
        return
    end

    local id = schedule_add()
    log.warn('Fencing actuated, reapply scheduled (fiber %d)', id)
end

local function fencing_cancel()
    if vars.fencing_fiber == nil then
        return
    end
    if vars.fencing_fiber:status() ~= 'dead' then
        vars.fencing_fiber:cancel()
    end
    vars.fencing_fiber = nil
end

local function fencing_start()
    fencing_cancel()

    vars.fencing_fiber = fiber.new(fencing_watch)
    vars.fencing_fiber:name('cartridge.fencing')
end

local function synchro_promote()
    if vars.enable_synchro_mode == true
    and vars.mode == 'stateful'
    and vars.consistency_needed
    and vars.cache.is_leader
    and not vars.failover_paused
    and not vars.failover_suppressed
    and box.ctl.promote ~= nil
    then
        local ok, err = pcall(box.ctl.promote)
        fiber.testcancel()
        if ok ~= true then
            log.error('Failed to promote: %s', err)
        end
        return err
    end
end

local function synchro_demote()
    local box_info = box.info
    if box_info.synchro ~= nil
    and box_info.synchro.queue ~= nil
    and box_info.synchro.queue.owner ~= 0
    and box_info.synchro.queue.owner == box_info.id
    and box.ctl.demote ~= nil then
        local ok, err = pcall(box.ctl.demote)
        fiber.testcancel()
        if ok ~= true then
            log.error('Failed to demote: %s', err)
        end
        return err
    end
end

local function constitute_oneself(active_leaders, opts)
    checks('table', {
        timeout = 'number',
    })

    local topology_cfg = vars.clusterwide_config:get_readonly('topology')

    if active_leaders[vars.replicaset_uuid] ~= vars.instance_uuid then
        -- I'm not a leader
        vars.cache.is_vclockkeeper = false
        vars.cache.is_leader = false
        vars.cache.is_rw = topology_cfg.replicasets[vars.replicaset_uuid].all_rw
        return true
    end

    -- Get ready to become a leader
    if not vars.consistency_needed then
        vars.cache.is_vclockkeeper = false
        vars.cache.is_leader = true
        vars.cache.is_rw = true
        return true
    elseif vars.cache.is_vclockkeeper then
        -- I'm already a vclockkeeper
        return true
    end

    local deadline = fiber.clock() + opts.timeout

    -- Go to the external state provider
    local session = assert(vars.client):get_session()
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    -- Query current vclockkeeper
    -- WARNING: implicit yield
    local vclockkeeper, err = session:get_vclockkeeper(vars.replicaset_uuid)
    fiber.testcancel()
    if err ~= nil then
        return nil, SwitchoverError:new(err)
    end

    if vclockkeeper == nil then
        -- It's absent, no need to wait anyone
        goto set_vclockkeeper
    elseif vclockkeeper.instance_uuid == vars.instance_uuid then
        -- It's me already, but vclock still should be persisted
        goto set_vclockkeeper
    end

    do
        -- Go to the vclockkeeper and query its LSN
        local vclockkeeper_uuid = vclockkeeper.instance_uuid
        local vclockkeeper_srv = topology_cfg.servers[vclockkeeper_uuid]
        if vclockkeeper_srv == nil then
            return nil, SwitchoverError:new('Alien vclockkeeper %q',
                vclockkeeper.instance_uuid
            )
        end

        local vclockkeeper_uri = vclockkeeper_srv.uri

        local timeout = deadline - fiber.clock()
        -- WARNING: implicit yield
        local vclockkeeper_info, err = errors.netbox_call(
            pool.connect(vclockkeeper_uri, {wait_connected = false}),
            -- get_lsn timeout may be negative. It's ok.
            '__cartridge_failover_get_lsn', {timeout - vars.options.NETBOX_CALL_TIMEOUT},
            -- wake up strictly before the deadline.
            {timeout = timeout}
        )
        fiber.testcancel()

        if vclockkeeper_info == nil then
            return nil, SwitchoverError:new(err)
        end

        -- Wait async replication to arrive
        -- WARNING: implicit yield
        local timeout = deadline - fiber.clock()
        local ok = utils.wait_lsn(
            vclockkeeper_info.id,
            vclockkeeper_info.lsn,
            vars.options.WAITLSN_PAUSE,
            timeout
        )
        fiber.testcancel()
        if not ok then
            return nil, SwitchoverError:new(
                "Can't catch up with the vclockkeeper"
            )
        end
    end

    -- The last one thing: persist our vclock
    ::set_vclockkeeper::
    local vclock = box.info.vclock

    -- WARNING: implicit yield
    local ok, err = session:set_vclockkeeper(
        vars.replicaset_uuid, vars.instance_uuid, vclock
    )
    fiber.testcancel()

    if ok == nil then
        return nil, SwitchoverError:new(err)
    end

    -- Hooray, instance is a legal vclockkeeper now.
    vars.cache.is_vclockkeeper = true
    vars.cache.is_leader = true
    vars.cache.is_rw = true

    log.info('Vclock persisted: %s. Consistent switchover succeeded',
        json.encode(setmetatable(vclock, {_serialize = 'sequence'}))
    )

    return true
end

function reconfigure_all(active_leaders)
    local confapplier = require('cartridge.confapplier')
::start_over::

    local t1 = fiber.clock()
    -- WARNING: implicit yield
    local ok, err = constitute_oneself(active_leaders, {
        timeout = vars.options.WAITLSN_TIMEOUT,
    })
    fiber.testcancel()
    local t2 = fiber.clock()

    if not ok then
        log.info("Consistency isn't reached yet: %s", err.err)
        fiber.sleep(t1 + vars.options.WAITLSN_TIMEOUT - t2)
        goto start_over
    end

    -- WARNING: implicit yield
    -- The event may arrive while two-phase commit is in progress.
    -- We should wait for the appropriate state.
    local state = confapplier.wish_state('RolesConfigured', math.huge)
    fiber.testcancel()

    if state ~= 'RolesConfigured' then
        log.info('Skipping failover step - state is %s', state)
        return
    end

    fiber.self().storage.is_busy = true
    confapplier.set_state('ConfiguringRoles')

    if vars.fencing_enabled
    and vars.cache.is_leader
    and vars.consistency_needed
    then
        fencing_start()
    end

    local ok, err = FailoverError:pcall(function()
        vars.failover_trigger_cnt = vars.failover_trigger_cnt + 1
        box.cfg({
            read_only = not vars.cache.is_rw,
        })
        err = synchro_promote()
        if err ~= nil then
            error(err)
        end

        local state = 'RolesConfigured'
        for _, role_name in ipairs(vars.all_roles) do
            local mod = service_registry.get(role_name)
            log.info('Applying "%s" role config from failover', role_name)
            local start_time = clock.monotonic()
            local _, err = apply_config(mod)
            if err then
                log.error('Role %q failover failed', mod.role_name)
                log.error('%s', err)
                log.info('Failed to apply "%s" role config from failover in %.6f sec',
                    role_name, clock.monotonic() - start_time)
                state = 'OperationError'
            else
                log.info('Successfully applied "%s" role config from failover in %.6f sec',
                    role_name, clock.monotonic() - start_time)
            end
        end

        for _, role_name in ipairs(vars.all_roles) do
            local mod = service_registry.get(role_name)
            on_apply_config(mod, state)
        end

        return true
    end)

    if ok then
        log.info('Failover step finished')
    else
        log.warn('Failover step failed: %s', err)
    end
    confapplier.set_state('RolesConfigured')
end

--- Lock failover if failover suppressing is on.
-- @function check_suppressing_lock
-- @local
local function check_suppressing_lock()
    while true do
        vars.failover_trigger_cnt = 0
        fiber.sleep(vars.suppress_timeout or math.huge)
        if vars.failover_suppressed == false then
            if vars.failover_trigger_cnt > vars.suppress_threshold then
                vars.failover_suppressed = true
            end
        elseif vars.failover_suppressed == true then
            vars.failover_suppressed = false
        end
    end
end

local function suppressing_cancel()
    if vars.suppress_fiber == nil then
        return
    end
    if vars.suppress_fiber:status() ~= 'dead' then
        vars.suppress_fiber:cancel()
    end
    vars.suppress_fiber = nil
end

--- Repeatedly fetch new appointments and reconfigure roles.
--
-- @function failover_loop
-- @local
local function failover_loop(args)
    checks({
        get_appointments = 'function',
    })
    while true do
        -- WARNING: implicit yield
        local appointments, err = FailoverError:pcall(args.get_appointments)
        fiber.testcancel()

        local csw1 = utils.fiber_csw()

        if appointments == nil then
            log.warn('%s', err.err)
            vars.failover_err = FailoverError:new(
                "Error fetching appointments: %s", err.err
            )
            goto continue
        end

        vars.failover_err = nil

        if vars.failover_paused == true then
            log.warn("Failover is paused, appointments don't apply")
            goto continue
        end

        if vars.failover_suppressed == true then
            log.warn("Failover is suppressed, appointments don't apply")
            goto continue
        end

        if accept_appointments(appointments) then
            local id = schedule_add()
            log.info(
                'Failover triggered, reapply' ..
                ' scheduled (fiber %d)', id
            )
        end

        ::continue::
        local csw2 = utils.fiber_csw()
        assert(csw1 == csw2, 'Unexpected yield')
    end
end

------------------------------------------------------------------------

--- Initialize the failover module.
-- @function cfg
-- @local
local function cfg(clusterwide_config, opts)
    checks('ClusterwideConfig', '?table')
    if opts == nil then
        opts = {}
    end

    if vars.client then
        vars.client:drop_session()
        vars.client = nil
    end

    suppressing_cancel()
    if opts.enable_failover_suppressing then
        local opts = argparse.get_opts{
            failover_suppress_threshold = 'number',
            failover_suppress_timeout = 'number',
        }
        vars.suppress_threshold = opts.failover_suppress_threshold or math.huge
        vars.suppress_timeout = opts.failover_suppress_timeout or math.huge
        vars.suppress_fiber = fiber.new(check_suppressing_lock)
        vars.suppress_fiber:name('cartridge.suppress_failover')
    end

    vars.enable_synchro_mode = opts.enable_synchro_mode

    if opts.disable_raft_on_small_clusters ~= nil then
        vars.disable_raft_on_small_clusters = opts.disable_raft_on_small_clusters
    end

    fencing_cancel()
    leader_autoreturn.cancel()
    schedule_clear()
    assert(next(vars.schedule) == nil)

    if vars.failover_fiber ~= nil then
        if vars.failover_fiber:status() ~= 'dead' then
            vars.failover_fiber:cancel()
        end
        vars.failover_fiber = nil
    end

    vars.failover_err = nil

    local confapplier = require('cartridge.confapplier')
    vars.replicaset_uuid = confapplier.get_replicaset_uuid()
    vars.instance_uuid = confapplier.get_instance_uuid()
    vars.all_roles = require('cartridge.roles').get_all_roles()

    vars.clusterwide_config = clusterwide_config
    local topology_cfg = clusterwide_config:get_readonly('topology')
    local failover_cfg = topology.get_failover_params(topology_cfg)
    local first_appointments

    -- disable raft if it was enabled
    if vars.mode == 'raft' and failover_cfg.mode ~= 'raft' then
        local err = raft_failover.disable()
        if err ~= nil then
            ApplyConfigError:new(
                'Unable to disable Raft failover: %q',
                err
            )
        end
    end

    if vars.mode == 'stateful' and failover_cfg.mode ~= 'stateful' and failover_cfg.mode ~= 'raft' then
        local err = synchro_demote()
        if err ~= nil then
            ApplyConfigError:new(
                'Unable to demote: %q',
                err
            )
        end
    end

    if failover_cfg.mode == 'disabled' then
        log.info('Failover disabled')
        vars.fencing_enabled = false
        vars.consistency_needed = false
        first_appointments = _get_appointments_disabled_mode(topology_cfg)

    elseif failover_cfg.mode == 'eventual' then
        log.info('Eventual failover enabled')
        vars.fencing_enabled = false
        vars.consistency_needed = false
        first_appointments = _get_appointments_eventual_mode(topology_cfg)

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                vars.membership_notification:wait()
                return _get_appointments_eventual_mode(topology_cfg)
            end,
        })
        vars.failover_fiber:name('cartridge.eventual-failover')

    elseif failover_cfg.mode == 'stateful' then
        local replicaset_uuid = vars.replicaset_uuid
        if topology_cfg.replicasets[replicaset_uuid].all_rw then
            -- Replicasets with all_rw flag imply that
            -- consistent switchover isn't necessary
            vars.consistency_needed = false
            local err = synchro_demote()
            if err ~= nil then
                ApplyConfigError:new(
                    'Unable to demote: %q',
                    err
                )
            end

        elseif #topology.get_leaders_order(topology_cfg, replicaset_uuid, nil) == 1 then
            -- Replicaset consists of a single server
            -- consistent switchover isn't necessary
            vars.consistency_needed = false
            local err = synchro_demote()
            if err ~= nil then
                ApplyConfigError:new(
                    'Unable to demote: %q',
                    err
                )
            end
        else
            vars.consistency_needed = true
        end

        if failover_cfg.state_provider == 'tarantool' then
            local params = assert(failover_cfg.tarantool_params)
            vars.client = stateboard_client.new({
                uri = assert(params.uri),
                password = params.password,
                call_timeout = vars.options.NETBOX_CALL_TIMEOUT,
            })

            log.info(
                'Stateful failover enabled with stateboard at %s',
                params.uri
            )
        elseif failover_cfg.state_provider == 'etcd2' then
            local params = assert(failover_cfg.etcd2_params)
            vars.client = etcd2_client.new({
                endpoints = params.endpoints,
                prefix = params.prefix,
                username = params.username,
                password = params.password,
                lock_delay = params.lock_delay,
                request_timeout = vars.options.NETBOX_CALL_TIMEOUT,
            })

            log.info(
                'Stateful failover enabled with etcd-v2 at %s',
                table.concat(params.endpoints, ', ')
            )
        else
            return nil, ApplyConfigError:new(
                'Unknown failover state provider %q',
                failover_cfg.state_provider
            )
        end

        vars.fencing_enabled = failover_cfg.fencing_enabled
        vars.fencing_timeout = failover_cfg.fencing_timeout
        vars.fencing_pause = failover_cfg.fencing_pause

        -- WARNING: implicit yield
        vars.cookie_check_err = nil
        if vars.cache.is_leader and failover_cfg.check_cookie_hash ~= false
        and package.loaded['cartridge.service-registry'].get('failover-coordinator') ~= nil then
            local ok, err = vars.client:set_identification_string(cluster_cookie.get_cookie_hash())
            if not ok then
                vars.cookie_check_err = err
                log.error(err)
            end
        end

        -- WARNING: implicit yield
        local appointments, err = _get_appointments_stateful_mode(vars.client, 0)
        if appointments == nil then
            log.warn('Failed to get first appointments: %s', err)
            vars.failover_err = FailoverError:new(
                "Error fetching first appointments: %s", err.err
            )
            first_appointments = {}
        else
            first_appointments = appointments
        end

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                return _get_appointments_stateful_mode(vars.client,
                    vars.options.LONGPOLL_TIMEOUT
                )
            end,
        })
        vars.failover_fiber:name('cartridge.stateful-failover')

        leader_autoreturn.cfg(failover_cfg, topology_cfg)

    elseif failover_cfg.mode == 'raft' then
        local ok, err = ApplyConfigError:pcall(raft_failover.check_version)
        if not ok then
            return nil, err
        end

        if topology_cfg.replicasets[vars.replicaset_uuid].all_rw then
            return nil, ApplyConfigError:new("Raft failover can't be enabled with ALL_RW replicasets")
        end
        vars.fencing_enabled = false
        vars.consistency_needed = false

        -- Raft failover can be enabled only on replicasets of 3 or more instances
        if vars.disable_raft_on_small_clusters
        and #topology.get_leaders_order(
            topology_cfg, vars.replicaset_uuid, nil, {only_electable = false, only_enabled = true}) < 3
        then
            first_appointments = _get_appointments_disabled_mode(topology_cfg)
            log.warn('Not enough instances to enable Raft failover')
            raft_failover.disable()
        else
            local ok, err = ApplyConfigError:pcall(raft_failover.cfg)
            if not ok then
                return nil, err
            end
            first_appointments = raft_failover.get_appointments(topology_cfg)
            log.info('Raft failover enabled')
        end

        vars.failover_fiber = fiber.new(failover_loop, {
            get_appointments = function()
                vars.membership_notification:wait()
                return raft_failover.get_appointments(topology_cfg)
            end,
        })
        vars.failover_fiber:name('cartridge.raft-failover')
    else
        return nil, ApplyConfigError:new(
            'Unknown failover mode %q',
            failover_cfg.mode
        )
    end

    require("membership.options").SUSPECT_TIMEOUT_SECONDS =
        failover_cfg.failover_timeout

    accept_appointments(first_appointments)

    local ok, err = constitute_oneself(vars.cache.active_leaders, {
        timeout = vars.options.WAITLSN_TIMEOUT
    })
    if ok == nil then
        log.warn("Error reaching consistency: %s", err)
        if next(vars.schedule) == nil then
            local id = schedule_add()
            log.info(
                'Consistency not reached, another' ..
                ' attempt scheduled (fiber %d)', id
            )
        end
    end

    if vars.fencing_enabled
    and vars.cache.is_leader
    and vars.consistency_needed
    then
        fencing_start()
    end

    box.cfg({
        read_only = not vars.cache.is_rw,
    })

    vars.mode = failover_cfg.mode
    err = synchro_promote()
    if err ~= nil then
        ApplyConfigError:new(
            'Unable to promote: %q',
            err
        )
    end

    return true
end

--- Get map of replicaset leaders.
-- @function get_active_leaders
-- @local
-- @return {[replicaset_uuid] = instance_uuid,...}
local function get_active_leaders()
    return vars.cache.active_leaders
end

--- Check current instance leadership.
-- @function is_leader
-- @local
-- @treturn boolean true / false
local function is_leader()
    return vars.cache.is_leader
end

--- Check current instance writability.
-- @function is_rw
-- @local
-- @treturn boolean true / false
local function is_rw()
    return vars.cache.is_rw
end

--- Check if current instance has persisted his vclock.
-- @function is_vclockkeeper
-- @local
-- @treturn boolean true / false
local function is_vclockkeeper()
    return vars.cache.is_vclockkeeper
end

--- Check if failover paused on current instance.
-- @function is_paused
-- @local
-- @treturn boolean true / false
local function is_paused()
    return vars.failover_paused
end

--- Check if failover suppressed on current instance.
-- @function failover_suppressed
-- @local
-- @treturn boolean true / false
local function is_suppressed()
    return vars.failover_suppressed
end

--- Check if failover synchro mode enabled.
-- @function is_synchro_mode_enabled
-- @local
-- @treturn boolean true / false
local function is_synchro_mode_enabled()
    return vars.enable_synchro_mode
end

--- Check if current configuration implies consistent switchover.
-- @function consistency_needed
-- @local
-- @treturn boolean true / false
local function consistency_needed()
    return vars.consistency_needed
end

--- Get failover mode.
-- @function mode
-- @local
-- @treturn string
local function mode()
    return vars.mode
end

--- Get current stateful failover coordinator
-- @function get_coordinator
-- @treturn[1] table coordinator
-- @treturn[2] nil
-- @treturn[2] table Error description
local function get_coordinator()
    if vars.client == nil then
        return nil, StateProviderError:new("No state provider configured")
    end

    local session = vars.client.session
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    return session:get_coordinator()
end

local function get_error()
    if vars.failover_fiber ~= nil
    and vars.failover_fiber:status() == 'dead'
    then
        return FailoverError:new('Failover fiber is dead!')
    end

    return vars.failover_err
end

local function check_cookie_hash_error()
    return vars.cookie_check_err
end

--- Force inconsistent leader switching.
-- Do it by resetting vclockkeepers in state provider.
--
-- @function force_inconsistency
-- @local
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function force_inconsistency(leaders, skip_error_on_change)
    if vars.client == nil then
        return nil, StateProviderError:new("No state provider configured")
    end

    local session = vars.client.session
    if session == nil or not session:is_alive() then
        return nil, StateProviderError:new('State provider unavailable')
    end

    local err
    for replicaset_uuid, instance_uuid in pairs(leaders) do
        local _ok, _err = session:set_vclockkeeper(
            replicaset_uuid, instance_uuid, nil, skip_error_on_change
        )
        if _ok == nil then
            err = _err
            log.warn(
                'Forcing inconsistency for %s failed: %s', instance_uuid,
                errors.is_error_object(_err) and _err.err or _err
            )
        end
    end

    if err ~= nil then
        return nil, err
    end

    return true
end

--- Wait when promoted instances become vclockkeepers.
--
-- @function wait_consistency
-- @local
-- @tparam {[string]=string,...} replicaset_uuid to leader_uuid mapping
--
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function wait_consistency(leaders)
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    assert(topology_cfg.servers)

    local uri_list = {}
    for _, instance_uuid in pairs(leaders) do
        assert(topology_cfg.servers[instance_uuid])
        table.insert(uri_list, topology_cfg.servers[instance_uuid].uri)
    end

    local timeout = vars.options.WAITLSN_TIMEOUT
    local _, err = pool.map_call(
        '_G.__cartridge_failover_wait_rw', {timeout},
        {
            uri_list = uri_list,
            timeout = timeout + vars.options.NETBOX_CALL_TIMEOUT,
        }
    )

    if err ~= nil then
        log.warn("Waiting consistent switchover didn't succeed: %s", err)
        local _, err = next(err.suberrors)
        return nil, err
    end

    return true
end

--- Set internal failover options.
--
-- Available options are: WAITLSN_PAUSE, WAITLSN_TIMEOUT, LONGPOLL_TIMEOUT, NETBOX_CALL_TIMEOUT
--
-- @function set_options
-- @local
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function set_options(opts)
    checks('table')
    for k, v in pairs(opts) do
        if vars.options[k] == nil then
            return nil, SetOptionsError:new(('Invalid option %s'):format(k))
        end
        if type(v) ~= "number" then
            return nil, SetOptionsError:new(('Invalid option %s value, expected number'):format(k))
        end
    end
    for k, v in pairs(opts) do
        vars.options[k] = v
    end
    return true
end

return {
    cfg = cfg,
    get_active_leaders = get_active_leaders,
    get_coordinator = get_coordinator,
    get_error = get_error,
    check_cookie_hash_error = check_cookie_hash_error,
    set_options = set_options,

    consistency_needed = consistency_needed,
    is_vclockkeeper = is_vclockkeeper,
    is_leader = is_leader,
    is_rw = is_rw,
    is_paused = is_paused,
    is_suppressed = is_suppressed,
    is_synchro_mode_enabled = is_synchro_mode_enabled,
    mode = mode,

    force_inconsistency = force_inconsistency,
    wait_consistency = wait_consistency,
}
