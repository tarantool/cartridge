#!/usr/bin/env tarantool

--- Make decisions regarding instances leadership.
--
-- Failover can operate in two modes:
--
-- * In `disabled` mode the leader is the first server configured in
--   `topology.replicsets[].master` array.
-- * In `eventual` mode the leader isn't elected consistently.
--   Instead, every instance in cluster thinks the leader is the
--   first **healthy** server in replicaset, while instance health is
--   determined according to membership status (the SWIM protocol).
--
-- This module behavior depends on the instance state.
--
-- From the very beginig it reports `is_rw() == false`,
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
local fiber = require('fiber')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cartridge.vars').new('cartridge.failover')
local utils = require('cartridge.utils')
local topology = require('cartridge.topology')
local service_registry = require('cartridge.service-registry')

local FailoverError = errors.new_class('FailoverError')
local ApplyConfigError = errors.new_class('ApplyConfigError')
local ValidateConfigError = errors.new_class('ValidateConfigError')

vars:new('mode', 'disabled') -- disabled | eventual
vars:new('clusterwide_config')
vars:new('failover_fiber')
vars:new('cache', {
    active_leaders = nil,
    is_leader = false,
    is_rw = false,
})

local function _get_health_map(topology_cfg, mode)
    checks('table', 'string')
    assert(topology_cfg.replicasets ~= nil)

    local ret = {
        active_leaders = {--[[ [replicaset_uuid] = leader_uuid ]]},
        server_status = {--[[ [instance_uuid] = "good"|"bad" ]]},
    }

    for replicaset_uuid, _ in pairs(topology_cfg.replicasets) do
        local leaders = topology.get_leaders_order(
            topology_cfg, replicaset_uuid
        )

        for _, instance_uuid in ipairs(leaders) do
            local server = topology_cfg.servers[instance_uuid]
            local member = membership.get_member(server.uri)

            if member ~= nil
            and (member.status == 'alive' or member.status == 'suspect')
            and member.payload.error == nil
            and member.payload.uuid == instance_uuid then
                if ret.active_leaders[replicaset_uuid] == nil
                and mode == 'eventual'
                then
                    ret.active_leaders[replicaset_uuid] = instance_uuid
                end
                ret.server_status[instance_uuid] = "good"
            else
                ret.server_status[instance_uuid] = "bad"
            end
        end

        if ret.active_leaders[replicaset_uuid] == nil then
            ret.active_leaders[replicaset_uuid] = leaders[1]
        end
    end

    return ret
end

local function refresh_cache()
    local topology_cfg = vars.clusterwide_config:get_readonly('topology')
    local health_map = _get_health_map(topology_cfg, vars.mode)

    local leader_uuid = health_map.active_leaders[box.info.cluster.uuid]
    local replicasets = topology_cfg.replicasets
    local all_rw = replicasets[box.info.cluster.uuid].all_rw

    vars.cache.active_leaders = health_map.active_leaders
    vars.cache.is_leader = box.info.uuid == leader_uuid
    vars.cache.is_rw = vars.cache.is_leader or all_rw

    if utils.deepcmp(health_map, vars.cache.health_map) then
        return false
    end
    vars.cache.health_map = health_map

    return true
end


local function _failover_role(mod)
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

local function _failover(cond)
    local confapplier = require('cartridge.confapplier')
    local all_roles = require('cartridge.roles').get_all_roles()

    local function failover_internal()
        box.cfg({
            read_only = not vars.cache.is_rw,
        })

        confapplier.set_state('ConfiguringRoles')
        for _, role_name in ipairs(all_roles) do
            local mod = service_registry.get(role_name)
            local _, err = _failover_role(mod)
            if err then
                log.error('Role %q failover failed: %s', mod.role_name, err)
            end
        end

        confapplier.set_state('RolesConfigured')
        log.info('Failover step finished')
        return true
    end

    while true do
        -- If failover_internal yields we may miss cond:broadcast
        -- so we force refresh_cache() and check if something changed
        if refresh_cache() then
            log.info('Failover triggered')
        else
            cond:wait()
            goto continue
        end

        local state = confapplier.get_state()
        if state ~= 'RolesConfigured' then
            log.info('Skipping failover step - state is %s', state)
            goto continue
        end

        local ok, err = FailoverError:pcall(failover_internal)
        if not ok then
            log.warn('%s', err)
        end
        ::continue::
    end
end

--- Initialize the failover module.
-- @function cfg
-- @local
local function cfg(clusterwide_config)
    checks('ClusterwideConfig')
    local topology_cfg = clusterwide_config:get_readonly('topology')
    assert(topology_cfg ~= nil)

    local new_mode = topology_cfg.failover and 'eventual' or 'disabled'
    if vars.mode ~= new_mode then
        log.info('Failover mode set to %q', vars.mode)
    end

    vars.clusterwide_config = clusterwide_config
    vars.mode = new_mode

    if vars.failover_cond == nil then
        vars.failover_cond = membership.subscribe()
    end

    if vars.failover_fiber == nil
    or vars.failover_fiber:status() == 'dead'
    then
        vars.failover_fiber = fiber.new(_failover, vars.failover_cond)
        vars.failover_fiber:name('cartridge.failover')
    end

    refresh_cache()
    box.cfg({
        read_only = not vars.cache.is_rw,
    })
    return true
end

--- Get map of replicaset leaders.
-- @function get_active_leaders
-- @local
-- @return {[replicaset_uuid] = instance_uuid,...}
local function get_active_leaders()
    if vars.cache.active_leaders ~= nil then
        return vars.cache.active_leaders
    end

    local confapplier = require('cartridge.confapplier')
    local topology_cfg = confapplier.get_readonly('topology')
    if topology_cfg == nil then
        return {}
    end
    local health_map = _get_health_map(topology_cfg, 'disabled')
    return health_map.active_leaders
end

return {
    cfg = cfg,
    get_active_leaders = get_active_leaders,

    --- Check current instance leadership.
    -- @function is_leader
    -- @local
    -- @treturn boolean true / false
    is_leader = function() return vars.cache.is_leader end,

    --- Check current instance writability.
    -- @function is_rw
    -- @local
    -- @treturn boolean true / false
    is_rw = function() return vars.cache.is_rw end,
}
