#!/usr/bin/env tarantool
-- luacheck: globals box

local log = require('log')
local fio = require('fio')
local yaml = require('yaml').new()
local fiber = require('fiber')
local errors = require('errors')
local checks = require('checks')
local vshard = require('vshard')
local membership = require('membership')

local vars = require('cluster.vars').new('cluster.confapplier')
local pool = require('cluster.pool')
local utils = require('cluster.utils')
local topology = require('cluster.topology')
local service_registry = require('cluster.service-registry')

yaml.cfg({
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local e_yaml = errors.new_class('Parsing yaml failed')
local e_atomic = errors.new_class('Atomic call failed')
local e_rollback = errors.new_class('Rollback failed')
local e_failover = errors.new_class('Vshard failover failed')
local e_config_load = errors.new_class('Loading configuration failed')
local e_config_fetch = errors.new_class('Fetching configuration failed')
local e_config_apply = errors.new_class('Applying configuration failed')
local e_config_restore = errors.new_class('Restoring configuration failed')
local e_config_validate = errors.new_class('Invalid config')
local e_bootstrap_vshard = errors.new_class('Can not bootstrap vshard router now')

vars:new('conf')
vars:new('locks', {})
vars:new('applier_fiber', nil)
vars:new('applier_channel', nil)
vars:new('failover_fiber', nil)
vars:new('failover_cond', nil)

local function load_from_file(filename)
    checks('string')
    if not utils.file_exists(filename) then
        return nil, e_config_load:new('file %q does not exist', filename)
    end

    local raw, err = utils.file_read(filename)
    if not raw then
        return nil, err
    end

    local confdir = fio.dirname(filename)

    local conf, err = e_yaml:pcall(yaml.decode, raw)
    if not conf then
        if not err then
            return nil, e_config_load:new('file %q is empty', filename)
        end

        return nil, err
    end

    local function _load(tbl)
        for k, v in pairs(tbl) do
            if type(v) == 'table' then
                local err
                if v['__file'] then
                    tbl[k], err = utils.file_read(confdir .. '/' .. v['__file'])
                else
                    tbl[k], err = _load(v)
                end
                if err then
                    return nil, err
                end
            end
        end
        return tbl
    end

    local conf, err = _load(conf)

    return conf, err
end

local function get_current(section)
    checks('?string')
    if vars.conf == nil then
        return nil
    end

    if section == nil then
        return table.deepcopy(vars.conf)
    else
        return table.deepcopy(vars.conf[section])
    end
end

local function restore_from_workdir(workdir)
    checks('string')
    e_config_restore:assert(
        vars.conf == nil,
        'config already loaded'
    )

    local conf, err = load_from_file(
        utils.pathjoin(workdir, 'config.yml')
    )

    if not conf then
        log.error('%s', err)
        return nil, err
    end

    vars.conf = conf
    topology.set(conf.topology)

    return table.deepcopy(conf)
end

local function fetch_from_uri(uri)
    local conn, err = pool.connect(uri)
    if conn == nil then
        return nil, err
    end

    return conn:eval('return package.loaded["cluster.confapplier"].get_current()')
end

local function fetch_from_membership()
    local conf = get_current()
    if conf then
        if conf.topology.servers[box.info.uuid] == nil
        or conf.topology.servers[box.info.uuid] == 'expelled'
        or utils.table_count(conf.topology.servers) == 1
        then
            return conf
        end
    end

    local candidates = {}
    for uri, member in membership.pairs() do
        if (member.status ~= 'alive') -- ignore non-alive members
        or (member.payload.uuid == nil)  -- ignore non-configured members
        or (member.payload.error ~= nil) -- ignore misconfigured members
        or (conf and member.payload.uuid == box.info.uuid) -- ignore myself
        or (conf and conf.topology.servers[member.payload.uuid] == nil) -- ignore aliens
        then
            -- ignore that member
        else

            table.insert(candidates, uri)
        end
    end

    if #candidates == 0 then
        return nil
    end

    return e_config_fetch:pcall(fetch_from_uri, candidates[math.random(#candidates)])
end

local function validate(conf_new)
    e_config_validate:assert(
        type(conf_new) == 'table',
        'config must be a table'
    )

    local conf_old = vars.conf or {}

    e_config_validate:assert(
        topology.validate(conf_new.topology, conf_old.topology)
    )

    return true
end

local function _failover(cond)
    while true do
        cond:wait()
        local bucket_count = vars.conf.bucket_count
        local cfg_new = topology.get_sharding_config()
        local cfg_old = nil

        local vshard_router = service_registry.get('vshard-router')
        local vshard_storage = service_registry.get('vshard-storage')

        if vshard_router and vshard_router.internal.current_cfg then
            local cfg_old = vshard_router.internal.current_cfg.sharding
        elseif vshard_storage and vshard_storage.internal.current_cfg then
            local cfg_old = vshard_storage.internal.current_cfg.sharding
        end

        if not utils.deepcmp(cfg_new, cfg_old) then
            if vshard_storage then
                log.info('Reconfiguring vshard.storage...')
                local cfg = {
                    sharding = cfg_new,
                    listen = box.cfg.listen,
                    bucket_count = bucket_count,
                    -- replication_connect_quorum = 0,
                }
                local _, err = e_failover:pcall(vshard_storage.cfg, cfg, box.info.uuid)
                if err then
                    log.error('%s', err)
                end
            end

            if vshard_router then
                log.info('Reconfiguring vshard.router...')
                local cfg = {
                    sharding = cfg_new,
                    bucket_count = bucket_count,
                    -- replication_connect_quorum = 0,
                }
                local _, err = e_failover:pcall(vshard_router.cfg, cfg, box.info.uuid)
                if err then
                    log.error('%s', err)
                end
            end

            log.info('Failover step finished')
        end
    end
end

local function _apply(channel)
    while true do
        local conf = channel:get()
        if not conf then
            return
        end

        vars.conf = conf
        topology.set(conf.topology)

        local replication = topology.get_replication_config(
            box.info.cluster.uuid
        )
        log.info('Setting replication to [%s]', table.concat(replication, ', '))
        local _, err = e_config_apply:pcall(box.cfg, {
            -- workaround for tarantool gh-3760
            replication_connect_timeout = 0.000001,
            replication_connect_quorum = 0,
            replication = replication,
        })
        if err then
            log.error('%s', err)
        end

        local roles = conf.topology.replicasets[box.info.cluster.uuid].roles

        if roles['vshard-storage'] then
            vshard.storage.cfg({
                sharding = topology.get_sharding_config(),
                bucket_count = conf.bucket_count,
                listen = box.cfg.listen,
            }, box.info.uuid)
            service_registry.set('vshard-storage', vshard.storage)

            -- local srv = storage.new()
            -- srv:apply_config(conf)
        end

        if roles['vshard-router'] then
            -- local srv = ibcore.server.new()
            -- srv:apply_config(conf)
            -- service_registry.set('ib-core', srv)
            vshard.router.cfg({
                sharding = topology.get_sharding_config(),
                bucket_count = conf.bucket_count,
            })
            service_registry.set('vshard-router', vshard.router)
        end
        log.info('Config applied')

        local failover_enabled = conf.topology.failover and (roles['vshard-storage'] or roles['vshard-router'])
        local failover_running = vars.failover_fiber and vars.failover_fiber:status() ~= 'dead'

        if failover_enabled and not failover_running then
            vars.failover_cond = membership.subscribe()
            vars.failover_fiber = fiber.create(_failover, vars.failover_cond)
            vars.failover_fiber:name('cluster.failover')
            log.info('vshard failover enabled')
        elseif not failover_enabled and failover_running then
            membership.unsubscribe(vars.failover_cond)
            vars.failover_fiber:cancel()
            vars.failover_fiber = nil
            vars.failover_cond = nil
            log.info('vshard failover disabled')
        end
    end
end

local function apply(conf)
    -- called by:
    -- 1. bootstrap.init_roles
    -- 2. clusterwide
    checks('table')

    if not vars.applier_channel then
        vars.applier_channel = fiber.channel(1)
    end

    if not vars.applier_fiber then
        vars.applier_fiber = fiber.create(_apply, vars.applier_channel)
        vars.applier_fiber:name('cluster.confapplier')
    end

    while not vars.applier_channel:has_readers() do
        -- TODO should we specify timeout here?
        if vars.applier_fiber:status() == 'dead' then
            return nil, e_config_apply:new('impossible due to previous error')
        end
        fiber.sleep(0)
    end

    local ok, err = utils.file_write(
        utils.pathjoin(box.cfg.memtx_dir, 'config.yml'),
        yaml.encode(conf)
    )

    if not ok then
        return nil, err
    end

    vars.applier_channel:put(conf)
    fiber.yield()
    return true
end

local function _clusterwide(conf_new)
    checks('table')

    local ok, err = validate(conf_new)
    if not ok then
        return nil, err
    end

    local conf_old = get_current()

    local servers_new = conf_new.topology.servers
    local servers_old = vars.conf.topology.servers

    local configured_uri_list = {}
    for uuid, _ in pairs(servers_new) do
        if servers_new[uuid] == 'expelled' then
            -- ignore expelled servers
        elseif servers_old[uuid] == nil then
            -- new servers bootstrap themselves through membership
            -- dont call nex.box on them
        else
            local uri = servers_new[uuid].uri
            local conn, err = pool.connect(uri)
            if conn == nil then
                return nil, err
            end
            local ok, err = e_config_validate:pcall(
                conn.eval, conn,
                'return package.loaded["cluster.confapplier"].validate(...)',
                {conf_new}
            )
            if not ok then
                return nil, err
            end
            configured_uri_list[uri] = false
        end
    end

    local _apply_error = nil
    for uri, _ in pairs(configured_uri_list) do
        local conn, err = pool.connect(uri)
        if conn == nil then
            return nil, err
        end
        log.info('Applying config on %s', uri)
        local ok, err = e_config_apply:pcall(
            conn.eval, conn,
            'return package.loaded["cluster.confapplier"].apply(...)',
            {conf_new}
        )
        if ok then
            configured_uri_list[uri] = true
        else
            log.error('%s', err)
            _apply_error = err
            break
        end
    end

    if _apply_error == nil then
        return true
    end

    for uri, configured in pairs(configured_uri_list) do
        if configured then
            log.info('Rollback config on %s', uri)
            local conn, err = pool.connect(uri)
            if conn == nil then
                return nil, err
            end
            local ok, err = e_rollback:pcall(
                conn.eval, conn,
                'return package.loaded["cluster.confapplier"].apply(...)',
                {conf_old}
            )
            if not ok then
                log.error(err)
            end
        end
    end

    return nil, _apply_error
end

local function clusterwide(conf_new)
    if vars.locks['clusterwide'] == true  then
        return nil, e_atomic:new('confapplier.clusterwide is already running')
    end

    box.session.su('admin')
    vars.locks['clusterwide'] = true
    local ok, err = e_config_apply:pcall(_clusterwide, conf_new)
    vars.locks['clusterwide'] = false

    return ok, err
end

return {
    get_current = get_current,
    load_from_file = load_from_file,
    restore_from_workdir = restore_from_workdir,
    fetch_from_membership = fetch_from_membership,

    validate = function(conf)
        return e_config_validate:pcall(validate, conf)
    end,
    apply = apply,
    clusterwide = clusterwide,
}
