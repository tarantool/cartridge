#!/usr/bin/env tarantool
-- luacheck: ignore _it

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')

local vars = require('cluster.vars').new('cluster.vshard-utils')
local pool = require('cluster.pool')
local utils = require('cluster.utils')
local topology = require('cluster.topology')
local confapplier = require('cluster.confapplier')

local e_config = errors.new_class('Invalid config')

vars:new('default_bucket_count', 30000)
vars:new('known_groups', nil
    -- {
    --     [group_name] = {bucket_count = ?number}
    -- }
)

local function validate_group_weights(group_name, topology)
    checks('string', 'table')
    local num_storages = 0
    local total_weight = 0

    for replicaset_uuid, replicaset in pairs(topology.replicasets or {}) do
        e_config:assert(
            (replicaset.weight or 0) >= 0,
            'replicasets[%s].weight must be non-negative, got %s', replicaset_uuid, replicaset.weight
        )

        local enabled_roles = confapplier.get_enabled_roles(replicaset.roles)
        if enabled_roles['vshard-storage'] and (replicaset.vshard_group or 'default') == group_name then
            num_storages = num_storages + 1
            total_weight = total_weight + (replicaset.weight or 0)
        end
    end

    if num_storages > 0 then
        e_config:assert(
            total_weight > 0,
            'At least one %s must have weight > 0',
            group_name and string.format('vshard-storage (%s)', group_name) or 'vshard-storage'
        )
    end
end

local function validate_group_upgrade(group_name, topology_new, topology_old)
    checks('string', 'table', 'table')
    local replicasets_new = topology_new.replicasets or {}
    local replicasets_old = topology_old.replicasets or {}
    local servers_old = topology_old.servers or {}

    for replicaset_uuid, replicaset_old in pairs(replicasets_old) do
        local replicaset_new = replicasets_new[replicaset_uuid]
        local storage_role_old = replicaset_old.roles['vshard-storage']
        local storage_role_new = replicaset_new and replicaset_new.roles['vshard-storage']

        if (storage_role_old) and (not storage_role_new)
        and ((replicaset_old.vshard_group or 'default') == group_name)
        then
            e_config:assert(
                (replicaset_old.weight == nil) or (replicaset_old.weight == 0),
                "replicasets[%s] is a vshard-storage which can't be removed", replicaset_uuid
            )

            local master_uuid
            if type(replicaset_old.master) == 'table' then
                master_uuid = replicaset_old.master[1]
            else
                master_uuid = replicaset_old.master
            end
            local master_uri = servers_old[master_uuid].uri
            local conn, err = pool.connect(master_uri)
            if not conn then
                error(err)
            end
            local buckets_count = conn:call('vshard.storage.buckets_count')
            e_config:assert(
                buckets_count == 0,
                "replicasets[%s] rebalancing isn't finished yet", replicaset_uuid
            )
        end

    end
end

local function validate_vshard_group(field, vsgroup_new, vsgroup_old)
    e_config:assert(
        type(vsgroup_new) == 'table',
        'section %s must be a table', field
    )
    e_config:assert(
        type(vsgroup_new.bucket_count) == 'number',
        '%s.bucket_count must be a number', field
    )
    e_config:assert(
        vsgroup_new.bucket_count > 0,
        '%s.bucket_count must be positive', field
    )
    if vsgroup_old ~= nil then
        e_config:assert(
            vsgroup_new.bucket_count == vsgroup_old.bucket_count,
            "%s.bucket_count can't be changed", field
        )
    end
    e_config:assert(
        type(vsgroup_new.bootstrapped) == 'boolean',
        '%s.bootstrapped must be true or false', field
    )
    local known_keys = {
        ['bucket_count'] = true,
        ['bootstrapped'] = true,
    }
    for k, _ in pairs(vsgroup_new) do
        e_config:assert(
            known_keys[k],
            'section %s has unknown parameter %q', field, k
        )
    end
end

local function validate_config(conf_new, conf_old)
    checks('table', 'table')

    local topology_new = conf_new.topology
    local topology_old = conf_old.topology or {}

    if conf_new.vshard_groups == nil then
        validate_vshard_group('vshard', conf_new.vshard, conf_old.vshard)
        validate_group_weights('default', topology_new)

        for replicaset_uuid, replicaset in pairs(topology_new.replicasets or {}) do
            e_config:assert(
                replicaset.vshard_group == nil or replicaset.vshard_group == 'default',
                "replicasets[%s] can't be added to vshard_group %q, cluster doesn't have any",
                replicaset_uuid, replicaset.vshard_group
            )
        end

        if conf_new.vshard.bootstrapped then
            validate_group_upgrade('default', topology_new, topology_old)
        end
    else
        e_config:assert(
            type(conf_new.vshard_groups) == 'table',
            'section vshard_groups must be a table'
        )

        for name, vsgroup in pairs(conf_new.vshard_groups) do
            e_config:assert(
                type(name) == 'string',
                'section vshard_groups must have string keys'
            )

            local groups_old = conf_old.vshard_groups or {}
            validate_vshard_group(('vshard_groups[%q]'):format(name), vsgroup, groups_old[name])
            validate_group_weights(name, topology_new)
        end

        for replicaset_uuid, replicaset_new in pairs(topology_new.replicasets or {}) do
            local replicaset_old
            if topology_old.replicasets then
                replicaset_old = topology_old.replicasets[replicaset_uuid]
            end

            if replicaset_old ~= nil and replicaset_old.vshard_group ~= nil then
                e_config:assert(
                    replicaset_new.vshard_group == replicaset_old.vshard_group,
                    "replicasets[%s].vshard_group can't be modified",
                    replicaset_uuid
                )
            end

            if replicaset_new.roles['vshard-storage'] then
                e_config:assert(
                    replicaset_new.vshard_group ~= nil,
                    "replicasets[%s] is a vshard-storage and must be assigned to a particular group",
                    replicaset_uuid
                )
                e_config:assert(
                    conf_new.vshard_groups[replicaset_new.vshard_group] ~= nil,
                    "replicasets[%s].vshard_group %q doesn't exist",
                    replicaset_uuid, replicaset_new.vshard_group
                )
            end
        end

        for name, vsgroup in pairs(conf_new.vshard_groups) do
            if vsgroup.bootstrapped then
                validate_group_upgrade(name, topology_new, topology_old)
            end
        end
    end

    return true
end

local function set_known_groups(vshard_groups, default_bucket_count)
    checks('nil|table', 'nil|number')
    vars.known_groups = vshard_groups
    vars.default_bucket_count = default_bucket_count
end

--- Get list of known vshard groups.
--
-- When cluster is bootstrapped obtains information from clusterwide config.
-- Before that - from `cluster.cfg({vshard_groups})` params.
--
-- For every known group it returns a table with keys `bootstrapped` and `bucket_count`.
-- In single-group mode it returns the only group 'default'.
-- If vshard is completely disabled (vshard-router role wasn't registered bu cluster.cfg)
-- returns empty table.
--
-- @function get_known_groups
-- @local
-- @treturn {[string]=table,...}
local function get_known_groups()
    local known_roles = confapplier.get_known_roles()
    if utils.table_find(known_roles, 'vshard-router') == nil then
        return {}
    end

    local vshard_groups
    if confapplier.get_readonly('vshard_groups') ~= nil then
        vshard_groups = confapplier.get_deepcopy('vshard_groups')
    elseif confapplier.get_readonly('vshard') ~= nil then
        vshard_groups = {
            default = confapplier.get_deepcopy('vshard')
        }
    elseif vars.known_groups ~= nil then
        vshard_groups = {}
        for name, g in pairs(vars.known_groups) do
            vshard_groups[name] = {
                bucket_count = g.bucket_count or vars.default_bucket_count,
                bootstrapped = false,
            }
        end
    else
        vshard_groups = {
            default = {
                bucket_count = vars.default_bucket_count,
                bootstrapped = false,
            }
        }
    end

    return vshard_groups
end

--- Get vshard configuration for particular group.
--
-- It can be passed to `vshard.router.cfg` and `vshard.storage.cfg`
--
-- @function get_vshard_config
-- @tparam nil|string group_name name of vshard storage group
-- @tparam table group_name name of vshard storage group
-- @treturn table
local function get_vshard_config(group_name, conf)
    checks('string', 'table')

    local sharding = {}
    local topology_cfg = topology.get()
    local active_masters = topology.get_active_masters()

    for _it, instance_uuid, server in fun.filter(topology.not_disabled, topology_cfg.servers) do
        local replicaset_uuid = server.replicaset_uuid
        local replicaset = topology_cfg.replicasets[replicaset_uuid]
        if replicaset.roles['vshard-storage'] and (replicaset.vshard_group or 'default') == group_name then
            if sharding[replicaset_uuid] == nil then
                sharding[replicaset_uuid] = {
                    replicas = {},
                    weight = replicaset.weight or 0.0,
                }
            end

            local replicas = sharding[replicaset_uuid].replicas
            replicas[instance_uuid] = {
                name = server.uri,
                uri = pool.format_uri(server.uri),
                master = (active_masters[replicaset_uuid] == instance_uuid),
            }
        end
    end

    local vshard_groups
    if conf.vshard_groups == nil then
        vshard_groups = {default = conf.vshard}
    else
        vshard_groups = conf.vshard_groups
    end

    local is_master = active_masters[box.info.cluster.uuid] == box.info.uuid
    local my_replicaset = topology_cfg.replicasets[box.info.cluster.uuid]
    local is_rw = is_master or my_replicaset.all_rw

    return {
        bucket_count = vshard_groups[group_name].bucket_count,
        sharding = sharding,
        read_only = not is_rw
    }
end

local function can_bootstrap_group(group_name, vsgroup)
    if vsgroup.bootstrapped then
        return false
    end

    local conf = confapplier.get_readonly()
    local vshard_cfg = get_vshard_config(group_name, conf)
    if next(vshard_cfg.sharding) == nil then
        return false
    end

    return true
end

local function can_bootstrap()
    local known_roles = confapplier.get_known_roles()
    if utils.table_find(known_roles, 'vshard-router') == nil then
        return false
    end

    local vshard_groups
    if confapplier.get_readonly('vshard_groups') ~= nil then
        vshard_groups = confapplier.get_readonly('vshard_groups')
    elseif confapplier.get_readonly('vshard') ~= nil then
        vshard_groups = {
            default = confapplier.get_readonly('vshard')
        }
    end

    if vshard_groups == nil then
        return false
    end

    for name, g in pairs(vshard_groups) do
        if can_bootstrap_group(name, g) then
            return true
        end
    end

    return false
end

return {
    validate_config = function(...)
        return e_config:pcall(validate_config, ...)
    end,

    set_known_groups = set_known_groups,
    get_known_groups = get_known_groups,

    get_vshard_config = get_vshard_config,
    can_bootstrap = can_bootstrap,
}
