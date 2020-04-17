-- luacheck: ignore _it

local fun = require('fun')
local checks = require('checks')
local errors = require('errors')

local vars = require('cartridge.vars').new('cartridge.vshard-utils')
local pool = require('cartridge.pool')
local roles = require('cartridge.roles')
local topology = require('cartridge.topology')
local failover = require('cartridge.failover')
local twophase = require('cartridge.twophase')
local confapplier = require('cartridge.confapplier')
local vshard_consts = require('vshard.consts')

local ValidateConfigError = errors.new_class('ValidateConfigError')

vars:new('default_bucket_count', 30000)
vars:new('known_groups', nil
    --{
    --    [group_name] = {
    --        bucket_count = number,
    --        rebalancer_max_receiving = number,
    --        collect_lua_garbage = boolean,
    --        collect_bucket_garbage_interval = number,
    --        sync_timeout = number,
    --        rebalancer_disbalance_threshold = number,
    --    }
    --}
)

local function validate_group_weights(group_name, topology)
    checks('string', 'table')
    local num_storages = 0
    local total_weight = 0

    for replicaset_uuid, replicaset in pairs(topology.replicasets or {}) do
        ValidateConfigError:assert(
            (replicaset.weight or 0) >= 0,
            'replicasets[%s].weight must be non-negative, got %s', replicaset_uuid, replicaset.weight
        )

        local enabled_roles = roles.get_enabled_roles(replicaset.roles)
        if enabled_roles['vshard-storage'] and (replicaset.vshard_group or 'default') == group_name then
            num_storages = num_storages + 1
            total_weight = total_weight + (replicaset.weight or 0)
        end
    end

    if num_storages > 0 then
        ValidateConfigError:assert(
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
            ValidateConfigError:assert(
                (replicaset_old.weight == nil) or (replicaset_old.weight == 0),
                "replicasets[%s] is a vshard-storage which can't be removed",
                replicaset_uuid
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
            ValidateConfigError:assert(
                buckets_count == 0,
                "replicasets[%s] rebalancing isn't finished yet",
                replicaset_uuid
            )
        end

    end
end

local function validate_vshard_group(field, vsgroup_new, vsgroup_old)
    ValidateConfigError:assert(
        type(vsgroup_new) == 'table',
        'section %s must be a table', field
    )
    ValidateConfigError:assert(
        type(vsgroup_new.bucket_count) == 'number',
        '%s.bucket_count must be a number', field
    )
    ValidateConfigError:assert(
        vsgroup_new.bucket_count > 0,
        '%s.bucket_count must be positive', field
    )
    if vsgroup_new.rebalancer_max_receiving ~= nil then
        ValidateConfigError:assert(
            type(vsgroup_new.rebalancer_max_receiving) == 'number',
            '%s.rebalancer_max_receiving must be a number', field
        )
        ValidateConfigError:assert(
            vsgroup_new.rebalancer_max_receiving > 0,
            '%s.rebalancer_max_receiving must be positive', field
        )
    end
    if vsgroup_new.collect_lua_garbage ~= nil then
        ValidateConfigError:assert(
            type(vsgroup_new.collect_lua_garbage) == 'boolean',
            '%s.collect_lua_garbage must be a boolean', field
        )
    end
    if vsgroup_new.sync_timeout ~= nil then
        ValidateConfigError:assert(
            type(vsgroup_new.sync_timeout) == 'number',
            '%s.sync_timeout must be a number', field
        )
        ValidateConfigError:assert(
            vsgroup_new.sync_timeout >= 0,
            '%s.sync_timeout must be non-negative', field
        )
    end
    if vsgroup_new.collect_bucket_garbage_interval ~= nil then
        ValidateConfigError:assert(
            type(vsgroup_new.collect_bucket_garbage_interval) == 'number',
            '%s.collect_bucket_garbage_interval must be a number', field
        )
        ValidateConfigError:assert(
            vsgroup_new.collect_bucket_garbage_interval > 0,
            '%s.collect_bucket_garbage_interval must be positive', field
        )
    end
    if vsgroup_new.rebalancer_disbalance_threshold ~= nil then
        ValidateConfigError:assert(
            type(vsgroup_new.rebalancer_disbalance_threshold) == 'number',
            '%s.rebalancer_disbalance_threshold must be a number', field
        )
        ValidateConfigError:assert(
            vsgroup_new.rebalancer_disbalance_threshold >= 0,
            '%s.rebalancer_disbalance_threshold must be non-negative', field
        )
    end
    if vsgroup_old ~= nil then
        ValidateConfigError:assert(
            vsgroup_new.bucket_count == vsgroup_old.bucket_count,
            "%s.bucket_count can't be changed", field
        )
    end
    ValidateConfigError:assert(
        type(vsgroup_new.bootstrapped) == 'boolean',
        '%s.bootstrapped must be true or false', field
    )
    local known_keys = {
        ['bucket_count'] = true,
        ['bootstrapped'] = true,
        ['rebalancer_max_receiving'] = true,
        ['collect_lua_garbage'] = true,
        ['sync_timeout'] = true,
        ['collect_bucket_garbage_interval'] = true,
        ['rebalancer_disbalance_threshold'] = true,
    }
    for k, _ in pairs(vsgroup_new) do
        ValidateConfigError:assert(
            known_keys[k],
            'section %s has unknown parameter %q', field, k
        )
    end
end

local function validate_config(conf_new, conf_old)
    checks('table', 'table')
    if conf_new.__type == 'ClusterwideConfig' then
        local err = "Bad argument #1 to validate_config" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end
    if conf_old.__type == 'ClusterwideConfig' then
        local err = "Bad argument #2 to validate_config" ..
            " (table expected, got ClusterwideConfig)"
        error(err, 2)
    end

    local topology_new = conf_new.topology
    local topology_old = conf_old.topology or {}

    if conf_new.vshard_groups == nil then
        validate_vshard_group('vshard', conf_new.vshard, conf_old.vshard)
        validate_group_weights('default', topology_new)

        for replicaset_uuid, replicaset in pairs(topology_new.replicasets or {}) do
            ValidateConfigError:assert(
                replicaset.vshard_group == nil or replicaset.vshard_group == 'default',
                "replicasets[%s] can't be added to vshard_group %q," ..
                " cluster doesn't have any",
                replicaset_uuid, replicaset.vshard_group
            )
        end

        if conf_new.vshard.bootstrapped then
            validate_group_upgrade('default', topology_new, topology_old)
        end
    else
        ValidateConfigError:assert(
            type(conf_new.vshard_groups) == 'table',
            'section vshard_groups must be a table'
        )

        for name, vsgroup in pairs(conf_new.vshard_groups) do
            ValidateConfigError:assert(
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
                ValidateConfigError:assert(
                    replicaset_new.vshard_group == replicaset_old.vshard_group,
                    "replicasets[%s].vshard_group can't be modified",
                    replicaset_uuid
                )
            end

            if replicaset_new.roles['vshard-storage'] then
                ValidateConfigError:assert(
                    replicaset_new.vshard_group ~= nil,
                    "replicasets[%s] is a vshard-storage and must be assigned to a particular group",
                    replicaset_uuid
                )
                ValidateConfigError:assert(
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
-- Before that - from `cartridge.cfg({vshard_groups})` params.
--
-- For every known group it returns a table with keys `bootstrapped` and `bucket_count`.
-- In single-group mode it returns the only group 'default'.
-- If vshard is completely disabled (vshard-router role wasn't registered by cartridge.cfg)
-- returns empty table.
--
-- @function get_known_groups
-- @local
-- @treturn {[string]=table,...}
local function get_known_groups()
    if roles.get_role('vshard-router') == nil then
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

    for _, g in pairs(vshard_groups) do
        if g.rebalancer_max_receiving == nil then
            g.rebalancer_max_receiving = vshard_consts.DEFAULT_REBALANCER_MAX_RECEIVING
        end

        if g.collect_lua_garbage == nil then
            g.collect_lua_garbage = false
        end

        if g.sync_timeout == nil then
            g.sync_timeout = vshard_consts.DEFAULT_SYNC_TIMEOUT
        end

        if g.collect_bucket_garbage_interval == nil then
            g.collect_bucket_garbage_interval = vshard_consts.DEFAULT_COLLECT_BUCKET_GARBAGE_INTERVAL
        end

        if g.rebalancer_disbalance_threshold == nil then
            g.rebalancer_disbalance_threshold = vshard_consts.DEFAULT_REBALANCER_DISBALANCE_THRESHOLD
        end
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
    local topology_cfg = confapplier.get_readonly('topology')
    assert(topology_cfg ~= nil)
    local active_leaders = failover.get_active_leaders()

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
                master = (active_leaders[replicaset_uuid] == instance_uuid),
            }
        end
    end

    local vshard_groups
    if conf.vshard_groups == nil then
        vshard_groups = {default = conf.vshard}
    else
        vshard_groups = conf.vshard_groups
    end

    return {
        bucket_count = vshard_groups[group_name].bucket_count,
        rebalancer_max_receiving = vshard_groups[group_name].rebalancer_max_receiving,
        collect_lua_garbage = vshard_groups[group_name].collect_lua_garbage,
        sync_timeout = vshard_groups[group_name].sync_timeout,
        collect_bucket_garbage_interval = vshard_groups[group_name].collect_bucket_garbage_interval,
        rebalancer_disbalance_threshold = vshard_groups[group_name].rebalancer_disbalance_threshold,
        sharding = sharding,
        read_only = not failover.is_rw(),
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
    if roles.get_role('vshard-router') == nil then
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

local function edit_vshard_options(group_name, vshard_options)
    checks(
        'string',
        {
            rebalancer_max_receiving = '?number',
            collect_lua_garbage = '?boolean',
            sync_timeout = '?number',
            collect_bucket_garbage_interval = '?number',
            rebalancer_disbalance_threshold = '?number'
        }
    )

    local patch = {
        vshard_groups = confapplier.get_deepcopy('vshard_groups'),
        vshard = confapplier.get_deepcopy('vshard')
    }

    local group
    if patch.vshard_groups ~= nil then
        group = patch.vshard_groups[group_name]
    elseif group_name == 'default' then
        group = patch.vshard
    end

    if group == nil then
        local err = ValidateConfigError:new(
            "vshard-group %q doesn't exist", group_name
        )
        return nil, err
    end

    for k, v in pairs(vshard_options) do
        group[k] = v
    end

    return twophase.patch_clusterwide(patch)
end

return {
    validate_config = function(...)
        return ValidateConfigError:pcall(validate_config, ...)
    end,

    set_known_groups = set_known_groups,
    get_known_groups = get_known_groups,

    get_vshard_config = get_vshard_config,
    can_bootstrap = can_bootstrap,
    edit_vshard_options = edit_vshard_options,
}
