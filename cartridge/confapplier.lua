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
local pool = require('cartridge.pool')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
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

vars:new('state')
vars:new('workdir')
vars:new('cwcfg_active')

vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

vars:new('box_opts', nil)
vars:new('boot_opts', nil)

local function boot_instance(opts)
    checks({
        workdir = 'string',
    })

    vars.workdir = workdir
    local config_filename = fio.pathjoin(workdir, 'config.yml')
    if utils.file_exists(filename) then
        return true
    end

    -- 1. if snapshot is there - init box
    -- 2. if clusterwide config is there - apply_config

    local ok, err = bootstrap.just_boot({
        workdir = opts.workdir,
        binary_port = advertise.service,
        bucket_count = opts.bucket_count,
        vshard_groups = vshard_groups,
        box_opts = box_opts,
    })


    local conf, err = ClusterwideConfig.load_from_file(filename)
    if conf == nil then
        return nil, err
    end

    return true
end

--- Validate configuration by all roles.
-- @function validate_config
-- @local
-- @tparam table conf_new
-- @tparam table conf_old
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function validate_config(conf_new, conf_old)
    if type(conf_new) ~= 'table'  then
        return nil, e_config_validate:new('config must be a table')
    end

    return roles.validate_config(conf_new, conf_old)
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

--- Apply the role configuration.
-- @function apply_config
-- @local
-- @tparam table conf
-- @treturn[1] boolean true
-- @treturn[2] nil
-- @treturn[2] table Error description
local function apply_config(conf)
    checks('table')
    vars.conf = utils.table_setro(conf)
    box.session.su('admin')

    local replication = topology.get_replication_config(
        conf.topology,
        box.info.cluster.uuid
    )

    topology.set(conf.topology)
    local my_replicaset = conf.topology.replicasets[box.info.cluster.uuid]
    local active_masters = topology.get_active_masters()
    local is_master = false
    if active_masters[box.info.cluster.uuid] == box.info.uuid then
        is_master = true
    end

    local is_rw = is_master or my_replicaset.all_rw

    local _, err = e_config_apply:pcall(box.cfg, {
        read_only = not is_rw,
        replication = replication,
    })
    if err then
        log.error('Box.cfg failed: %s', err)
    end

    local enabled_roles = get_enabled_roles(my_replicaset.roles)
    for _, mod in ipairs(vars.known_roles) do
        local role_name = mod.role_name
        if enabled_roles[role_name] then
            repeat -- until true
                if (service_registry.get(role_name) == nil)
                and (type(mod.init) == 'function')
                then
                    local _, _err = e_config_apply:pcall(mod.init,
                        {is_master = is_master}
                    )
                    if _err then
                        log.error('%s', _err)
                        err = err or _err
                        break
                    end
                end

                service_registry.set(role_name, mod)

                if type(mod.apply_config) == 'function' then
                    local _, _err = e_config_apply:pcall(
                        mod.apply_config, conf,
                        {is_master = is_master}
                    )
                    if _err then
                        log.error('%s', _err)
                        err = err or _err
                    end
                end
            until true
        else
            if (service_registry.get(role_name) ~= nil)
            and (type(mod.stop) == 'function')
            then
                local _, _err = e_config_apply:pcall(mod.stop,
                        {is_master = is_master}
                )
                if _err then
                    log.error('%s', err)
                    err = err or _err
                end
            end

            service_registry.set(role_name, nil)
        end
    end
    log.info('Config applied')

    local failover_enabled = conf.topology.failover
    local failover_running = vars.failover_fiber and vars.failover_fiber:status() ~= 'dead'

    if failover_enabled and not failover_running then
        vars.failover_cond = membership.subscribe()
        vars.failover_fiber = fiber.create(_failover, vars.failover_cond)
        vars.failover_fiber:name('cluster.failover')
        log.info('Failover enabled')
    elseif not failover_enabled and failover_running then
        membership.unsubscribe(vars.failover_cond)
        vars.failover_fiber:cancel()
        vars.failover_fiber = nil
        vars.failover_cond = nil
        log.info('Failover disabled')
    end

    if err then
        membership.set_payload('error', 'Config apply failed')
        return nil, err
    else
        membership.set_payload('ready', true)
        return true
    end
end

return {
    init = init,
    set_workdir = set_workdir,
    get_readonly = get_readonly,
    get_deepcopy = get_deepcopy,

    load_from_file = load_from_file,

    apply_config = apply_config,
    validate_config = validate_config,
}
