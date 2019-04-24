#!/usr/bin/env tarantool

local log = require('log')
local vshard = require('vshard')
local checks = require('checks')
local errors = require('errors')

local pool = require('cluster.pool')
local vars = require('cluster.vars').new('cluster.roles.vshard-storage')
local utils = require('cluster.utils')
local topology = require('cluster.topology')

local e_config = errors.new_class('Invalid config')

vars:new('vshard_cfg')

local function validate_weights(topology)
    checks('table')
    local num_storages = 0
    local total_weight = 0

    for replicaset_uuid, replicaset in pairs(topology.replicasets or {}) do
        e_config:assert(
            (replicaset.weight or 0) >= 0,
            'replicasets[%s].weight must be non-negative, got %s', replicaset_uuid, replicaset.weight
        )

        if replicaset.roles['vshard-storage'] then
            num_storages = num_storages + 1
            total_weight = total_weight + (replicaset.weight or 0)
        end
    end

    if num_storages > 0 then
        e_config:assert(
            total_weight > 0,
            'At least one vshard-storage must have weight > 0'
        )
    end
end


local function validate_upgrade(topology_new, topology_old)
    checks('table', 'table')
    local replicasets_new = topology_new.replicasets or {}
    local replicasets_old = topology_old.replicasets or {}
    local servers_old = topology_old.servers or {}

    for replicaset_uuid, replicaset_old in pairs(replicasets_old) do
        local replicaset_new = replicasets_new[replicaset_uuid]
        local storage_role_old = replicaset_old.roles['vshard-storage']
        local storage_role_new = replicaset_new and replicaset_new.roles['vshard-storage']

        if storage_role_old and not storage_role_new then
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

local function validate_config(conf_new, conf_old)
    checks('table', 'table')

    if type(conf_new.vshard) ~= 'table' then
        return nil, e_config:new('section "vshard" must be a table')
    elseif type(conf_new.vshard.bucket_count) ~= 'number' then
        return nil, e_config:new('vshard.bucket_count must be a number')
    elseif not (conf_new.vshard.bucket_count > 0) then
        return nil, e_config:new('vshard.bucket_count must be a positive')
    elseif type(conf_new.vshard.bootstrapped) ~= 'boolean' then
        return nil, e_config:new('vshard.bootstrapped must be true or false')
    end

    local topology_new = conf_new.topology
    local topology_old = conf_old.topology or {}
    validate_weights(topology_new)
    validate_upgrade(topology_new, topology_old)

    return true
end

local function apply_config(conf)
    checks('table')

    local vshard_cfg = {
        sharding = topology.get_vshard_sharding_config(),
        bucket_count = conf.vshard.bucket_count,
        listen = box.cfg.listen,
    }

    if utils.deepcmp(vshard_cfg, vars.vshard_cfg) then
        -- No reconfiguration required, skip it
        return
    end

    log.info('Reconfiguring vshard.storage...')
    vshard.storage.cfg(vshard_cfg, box.info.uuid)
    vars.vshard_cfg = vshard_cfg
end

local function init()
    rawset(_G, 'vshard', vshard)
end

local function stop()
    rawset(_G, 'vshard', nil)
end

return {
    role_name = 'vshard-storage',
    validate_config = validate_config,
    apply_config = apply_config,
    init = init,
    stop = stop,
}
