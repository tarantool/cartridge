#!/usr/bin/env tarantool

--- Configuration management primitives.
-- This module manages current instance state.
-- @module cartridge.confapplier

local log = require('log')
local fio = require('fio')
local fun = require('fun')
local yaml = require('yaml').new()
local fiber = require('fiber')
local errno = require('errno')
local errors = require('errors')
local checks = require('checks')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.confapplier')
local auth = require('cartridge.auth')
local utils = require('cartridge.utils')
local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local vshard_utils = require('cartridge.vshard-utils')
local remote_control = require('cartridge.remote-control')
local cluster_cookie = require('cartridge.cluster-cookie')
local service_registry = require('cartridge.service-registry')
local ClusterwideConfig = require('cartridge.clusterwide-config')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local e_yaml = errors.new_class('Parsing yaml failed')
local e_atomic = errors.new_class('Atomic call failed')
local e_failover = errors.new_class('Failover failed')
local e_config_load = errors.new_class('Loading configuration failed')
local e_config_fetch = errors.new_class('Fetching configuration failed')
local e_config_apply = errors.new_class('Applying configuration failed')
local e_config_validate = errors.new_class('Invalid config')
local e_register_role = errors.new_class('Can not register role')
local BoxError = errors.new_class('BoxError', {log_on_creation = true})
local StateError = errors.new_class('StateError', {log_on_creation = true})

vars:new('state', '')
vars:new('error')
vars:new('cwcfg') -- clusterwide config

vars:new('workdir')

vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

vars:new('box_opts', nil)
vars:new('boot_opts', nil)

local _transitions = {
    ['']
        -- Initial state.
        -- Function `confapplier.init()` wasn't called yet.
        = {'Unconfigured', 'ConfigFound', 'Error'},

-- init()
    ['Unconfigured']
        -- Remote control is running.
        -- Clusterwide config doesn't exist.
        = {'RecoveringSnapshot', 'Error'},

    ['ConfigFound']
        -- Remote control is running.
        -- Clusterwide config is found
        = {'ConfigLoaded', 'Error'},
    ['ConfigLoaded']
        -- Remote control is running.
        -- Loading clusterwide config succeeded.
        -- Validation succeeded too.
        = {'RecoveringSnapshot', 'Error'},

-- boot_instance
    ['RecoveringSnapshot']
        = {'SnapshotRecovered', 'Error'},
    ['SnapshotRecovered'] = {'RolesConfigured', 'Error'},

-- normal operation
    ['RolesConfigured'] = {'RolesConfigured', 'Error'},
    ['Error'] = {},
    -- Disabled
    -- Expelled
}
local function set_state(new_state, err)
    checks('string', '?')
    StateError:assert(
        utils.table_find(_transitions[vars.state], new_state),
        'invalid transition %s -> %s', vars.state, new_state
    )

    vars.state = new_state
    if new_state == 'Error' then
        log.error('Instance entering failure state: %s', err)
        vars.error = err
    end
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table cwcfg_new
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)

    return roles.validate_config(cwcfg, vars.cwcfg)
end


--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)
    assert(
        vars.state == 'SnapshotRecovered'
        or vars.state == 'RolesConfigured'
    )

    vars.cwcfg = cwcfg
    -- box.session.su('admin')

    local _, err = BoxError:pcall(box.cfg, {
        replication = topology.get_replication_config(
            cwcfg, box.info.cluster.uuid
        ),
    })
    if err then
        log.error('Box.cfg failed: %s', err)
        set_state('Error', err)
        return nil, err
    end

    local ok, err = roles.apply_config(cwcfg)
    if not ok then
        set_state('Error', err)
        return nil, err
    end

    set_state('RolesConfigured')
    return true
end


local function boot_instance(cwcfg)
    checks('ClusterwideConfig')
    assert(cwcfg.locked)
    assert(
        vars.state == 'Unconfigured' -- bootstraping from scratch
        or vars.state == 'ConfigLoaded' -- bootstraping from snapshot
    )

    set_state('RecoveringSnapshot', err)
    log.warn('Bootstrapping box.cfg...')

    if next(fio.glob(fio.pathjoin(vars.workdir, '*.snap'))) == nil then
        local err = errors.new('InitError',
            "Snapshot not found in %q, can't recover." ..
            " Did previous bootstrap attempt fail?",
            vars.workdir
        )
        set_state('Error', err)
        return nil, err
    end

    local instance_uuid =

    local box_opts = table.deepcopy(vars.box_opts)
    box_opts.wal_dir = workdir
    box_opts.memtx_dir = workdir
    box_opts.vinyl_dir = workdir
    box_opts.instance_uuid = instance_uuid
    box_opts.replicaset_uuid = replicaset_uuid
    box_opts.listen = box.NULL

    box.cfg(box_opts)

    local username = cluster_cookie.username()
    local password = cluster_cookie.cookie()

    log.info('Making sure user %q exists...', username)
    if not box.schema.user.exists(username) then
        error(('User %q does not exists'):format(username))
    end

    log.info('Granting replication permissions to %q...', username)

    BoxError:pcall(
        box.schema.user.grant,
        username, 'replication',
        nil, nil, {if_not_exists = true}
    )


    log.info('Setting password for user %q ...', username)
    BoxError:pcall(
        box.schema.user.passwd,
        username, password
    )

    membership.set_payload('uuid', box.info.uuid)
    local _, err = BoxError:pcall(
        box.cfg, {listen = listen}
    )

    if err ~= nil then
        log.error('Box initialization failed: %s', err)
        return nil, err
    end

    log.info("Box initialized successfully")
    return true


    local ok, err = init_box()
    if not ok then
        set_state('Error', err)
        return nil, err
    end

    -- 1. if snapshot is there - init box
    -- 2. if clusterwide config is there - apply_config




    local leader_uri = nil -- TODO
    if leader_uri == membership.myself().uri then
        -- I'm the leader
        box_opts.replication = nil
        if box_opts.read_only == nil then
            box_opts.read_only = false
        end
    else
        box_opts.replication = {leader_uri}
        if box_opts.read_only == nil then
            box_opts.read_only = true
        end
    end

    return apply_config(cwcfg)
end

local function init(opts)
    checks({
        workdir = 'string',
        box_opts = 'table',
        binary_port = 'number',
    })

    assert(vars.state == '')
    vars.workdir = opts.workdir
    vars.box_opts = opts.box_opts
    vars.binary_port = opts.binary_port

    local ok, err = remote_control.start('0.0.0.0', vars.binary_port, {
        username = cluster_cookie.username(),
        password = cluster_cookie.cookie(),
    })
    if not ok then
        set_state('Error', err)
        return nil, err
    end

    local config_filename = fio.pathjoin(vars.workdir, 'config.yml')
    if not utils.file_exists(config_filename) then
        set_state('Unconfigured')
    else
        set_state('ConfigFound')
        local cwcfg, err = ClusterwideConfig.load_from_file(config_filename)
        if cwcfg == nil then
            set_state('Error', err)
            return nil, err
        end

        vars.cwcfg = cwcfg
        local ok, err = validate_config(cwcfg)
        if not ok then
            set_state('Error', err)
            return nil, err
        end

        set_state('ConfigLoaded')
        fiber.new(boot_instance, cwcfg)
    end

    return true
end

local function _failover_role(mod, opts)
    if service_registry.get(mod.role_name) == nil then
        return true
    end

    if type(mod.apply_config) ~= 'function' then
        return true
    end

    if type(mod.validate_config) == 'function' then
        local ok, err = e_config_validate:pcall(
            mod.validate_config, vars.conf, vars.conf
        )
        if not ok then
            err = err or e_config_validate:new('validate_config() returned %s', ok)
            return nil, err
        end
    end

    return e_config_apply:pcall(
        mod.apply_config, vars.conf, opts
    )
end

-- local function _failover(cond)
--     local function failover_internal()
--         local active_masters = topology.get_active_masters()
--         local is_master = false
--         if active_masters[box.info.cluster.uuid] == box.info.uuid then
--             is_master = true
--         end
--         local opts = utils.table_setro({is_master = is_master})

--         local _, err = e_config_apply:pcall(box.cfg, {
--             read_only = not is_master,
--         })
--         if err then
--             log.error('Box.cfg failed: %s', err)
--         end

--         for _, mod in ipairs(vars.known_roles) do
--             local _, err = _failover_role(mod, opts)
--             if err then
--                 log.error('Role %q failover failed: %s', mod.role_name, err)
--             end
--         end

--         log.info('Failover step finished')
--         return true
--     end

--     while true do
--         cond:wait()
--         local ok, err = e_failover:pcall(failover_internal)
--         if not ok then
--             log.warn('%s', err)
--         end
--     end
-- end

return {
    init = init,
    boot_instance = boot_instance,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    get_state = get_state,
    get_bare_config = get_bare_config,
    get_active_config = get_active_config,
    -- load_from_file = load_from_file,

    apply_config = apply_config,
    validate_config = validate_config,
}
