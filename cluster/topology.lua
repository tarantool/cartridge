#!/usr/bin/env tarantool

-- this module incorporates information about
-- conf.servers and membership status

local uri = require('uri')
local fun = require('fun')
-- local log = require('log')
local checks = require('checks')
local errors = require('errors')
local membership = require('membership')

local vars = require('cluster.vars').new('cluster.topology')
local pool = require('cluster.pool')
local utils = require('cluster.utils')

local e_config = errors.new_class('Invalid cluster topology config')
vars:new('known_roles', {
    ['vshard-storage'] = true,
    ['vshard-router'] = true,
})
vars:new('topology', {
    servers = {
        -- ['instance-uuid-1'] = 'expelled',
        -- ['instance-uuid-2'] = {
        --     uri = 'localhost:3301',
        --     disabled = false,
        --     replicaset_uuid = 'replicaset-uuid-2',
        -- },
    },
    replicasets = {
        -- ['replicaset-uuid-1'] = 'expelled',
        -- ['replicaset-uuid-2'] = {
        --     roles = {
        --         ['role-1'] = true,
        --         ['role-2'] = true,
        --     },
        --     master = 'instance-uuid-2',
        --     weight = 1.0,
        -- }
    },
})

-- to be used in fun.filter
local function not_expelled(uuid, srv)
    return srv ~= 'expelled'
end

local function not_disabled(uuid, srv)
    return not_expelled(uuid, srv) and not srv.disabled
end

local function validate_schema(field, topology)
    checks('string', 'table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}

    e_config:assert(
        topology.failover == nil or type(topology.failover) == 'boolean',
        '%s.failover must be boolean, got %s', field, type(topology.failover)
    )

    e_config:assert(
        type(servers) == 'table',
        '%s.servers must be a table, got %s', field, type(servers)
    )

    e_config:assert(
        type(replicasets) == 'table',
        '%s.replicasets must be a table, got %s', field, type(replicasets)
    )

    for instance_uuid, server in pairs(servers) do
        e_config:assert(
            type(instance_uuid) == 'string',
            '%s.servers must have string keys', field
        )
        e_config:assert(
            checkers.uuid_str(instance_uuid),
            '%s.servers key %q is not a valid UUID', field, instance_uuid
        )

        local field = string.format('%s.servers[%s]', field, instance_uuid)

        if not_expelled(instance_uuid, server) then

            e_config:assert(
                type(server) == 'table',
                '%s must be either a table or the string "expelled"', field
            )
            e_config:assert(
                type(server.uri) == 'string',
                '%s.uri must be a string, got %s', field, type(server.uri)
            )
            e_config:assert(
                type(server.disabled or false) == 'boolean',
                '%s.disabled must be true or false', field
            )
            e_config:assert(
                type(server.replicaset_uuid) == 'string',
                '%s.replicaset_uuid must be a string, got %s', field, type(server.replicaset_uuid)
            )
            e_config:assert(
                checkers.uuid_str(server.replicaset_uuid),
                '%s.replicaset_uuid %q is not a valid UUID', field, server.replicaset_uuid
            )

            local known_keys = {
                ['uri'] = true,
                ['disabled'] = true,
                ['replicaset_uuid'] = true,
            }
            for k, v in pairs(server) do
                e_config:assert(
                    known_keys[k],
                    '%s has unknown parameter %q', field, k
                )
            end
        end
    end

    for replicaset_uuid, replicaset in pairs(replicasets) do
        e_config:assert(
            type(replicaset_uuid) == 'string',
            '%s.replicasets must have string keys', field
        )
        e_config:assert(
            checkers.uuid_str(replicaset_uuid),
            '%s.replicasets key %q is not a valid UUID', field, replicaset_uuid
        )

        local field = string.format('%s.replicasets[%s]', field, replicaset_uuid)

        e_config:assert(
            type(replicaset) == 'table',
            '%s must be a table', field
        )
        e_config:assert(
            type(replicaset.master) == 'string',
            '%s.master must be a string, got %s', field, type(replicaset.master)
        )
        e_config:assert(
            type(replicaset.roles) == 'table',
            '%s.roles must be a table, got %s', field, type(replicaset.roles)
        )

        e_config:assert(
            (replicaset.weight == nil) or (type(replicaset.weight) == 'number'),
            '%s.weight must be a number, got %s', field, type(replicaset.weight)
        )

        for k, v in pairs(replicaset.roles) do
            e_config:assert(
                type(k) == 'string',
                '%s.roles must have string keys', field
            )
            e_config:assert(
                type(v) == 'boolean',
                '%s.roles[%q] must be true or false', field, k
            )
        end

        local known_keys = {
            ['roles'] = true,
            ['master'] = true,
            ['weight'] = true,
        }
        for k, v in pairs(replicaset) do
            e_config:assert(
                known_keys[k],
                '%s has unknown parameter %q', field, k
            )
        end
    end

    local known_keys = {
        ['servers'] = true,
        ['replicasets'] = true,
        ['failover'] = true,
    }
    for k, v in pairs(topology) do
        e_config:assert(
            known_keys[k],
            '%s has unknown parameter %q', field, k
        )
    end
end

local function validate_consistency(topology)
    checks('table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}
    local known_uuids = {}

    for _it, instance_uuid, server in fun.filter(not_expelled, servers) do
        local field = string.format('servers[%s]', instance_uuid)
        e_config:assert(
            replicasets[server.replicaset_uuid] ~= nil,
            '%s.replicaset_uuid is not configured in replicasets table',
            field
        )
        known_uuids[server.replicaset_uuid] = true
    end

    local num_storages = 0
    local total_weight = 0

    for replicaset_uuid, replicaset in pairs(replicasets) do
        local field = string.format('replicasets[%s]', replicaset_uuid)

        e_config:assert(
            known_uuids[replicaset_uuid],
            '%s has no servers', field
        )

        local master_uuid = replicaset.master
        local master = servers[master_uuid]
        e_config:assert(
            master ~= nil,
            '%s.master does not exist', field
        )
        e_config:assert(
            not_expelled(master_uuid, master),
            '%s.master is expelled', field
        )
        e_config:assert(
            master.replicaset_uuid == replicaset_uuid,
            '%s.master belongs to another replicaset', field
        )
        e_config:assert(
            (replicaset.weight or 0) >= 0,
            '%s.weight must be non-negative, got %s', field, replicaset.weight
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


local function validate_availability(topology)
    checks('table')
    local servers = topology.servers or {}

    for _it, instance_uuid, server in fun.filter(not_disabled, servers) do
        local member = membership.get_member(server.uri)
        e_config:assert(
            member ~= nil,
            'Server %q is not in membership', server.uri
        )
        e_config:assert(
            member.status == 'alive',
            'Server %q is unreachable with status %q',
            server.uri, member.status
        )
        e_config:assert(
            (member.payload.uuid == nil) or (member.payload.uuid == instance_uuid),
            'Server %q bootstrapped with different uuid %q',
            server.uri, member.payload.uuid
        )
        e_config:assert(
            member.payload.error == nil,
            'Server %q has error: %s',
            server.uri, member.payload.error
        )
    end

    local myself = membership.myself()
    local myself_uuid = myself.payload.uuid
    if myself_uuid ~= nil then
        local srv = topology.servers[myself_uuid]
        e_config:assert(
            srv ~= nil,
            'Current instance %q is not listed in config', myself.uri
        )
        e_config:assert(
            not_expelled(myself_uuid, srv),
            'Current instance %q can not be expelled', myself.uri
        )
        e_config:assert(
            not_disabled(myself_uuid, srv),
            'Current instance %q can not be disabled', myself.uri
        )
    end
end

local function validate_upgrade(topology_new, topology_old)
    checks('table', 'table')
    local servers_new = topology_new.servers or {}
    local servers_old = topology_old.servers or {}
    local replicasets_new = topology_new.replicasets or {}
    local replicasets_old = topology_old.replicasets or {}

    -- validate that nobody was removed from previous config
    for instance_uuid, server_old in pairs(servers_old) do
        local server_new = servers_new[instance_uuid]
        e_config:assert(
            server_new ~= nil,
            'servers[%s] can not be removed from config', instance_uuid
        )
    end

    for _it, instance_uuid, server_new in fun.filter(not_expelled, servers_new) do
        local field = string.format('servers[%s]', instance_uuid)
        local server_old = servers_old[instance_uuid]

        if server_old then
            e_config:assert(
                not_expelled(instance_uuid, server_old),
                '%s has been expelled earlier', field
            )
            e_config:assert(
                server_old.replicaset_uuid == server_new.replicaset_uuid,
                '%s.replicaset_uuid can not be changed', field
            )
        end
    end

    for replicaset_uuid, replicaset_new in pairs(replicasets_new) do
        local replicaset_old = replicasets_old[replicaset_uuid]
        for role, enabled_new in pairs(replicaset_new.roles) do
            local enabled_old = replicaset_old and replicaset_old.roles[role]
            if enabled_new and not enabled_old then
                e_config:assert(
                    vars.known_roles[role],
                    'replicasets[%s] can not enable unknown role %q',
                    replicaset_uuid, tostring(role)
                )
            end
        end
    end

    for replicaset_uuid, replicaset_old in pairs(replicasets_old) do
        local replicaset_new = replicasets_new[replicaset_uuid]

        if replicaset_old.roles['vshard-storage'] then
            e_config:assert(
                replicaset_new ~= nil,
                'replicasets[%s] is a vshard-storage and can not be expelled', replicaset_uuid
            )
            e_config:assert(
                replicaset_new.roles['vshard-storage'] == true,
                'replicasets[%s].roles vshard-storage can not be disabled', replicaset_uuid
            )
        end
    end
end


local function validate(topology_new, topology_old)
    topology_old = topology_old or {}
    e_config:assert(
        type(topology_new) == 'table',
        'topology_new must be a table, got %s', type(topology_new)
    )
    e_config:assert(
        type(topology_old) == 'table',
        'topology_old must be a table, got %s', type(topology_old)
    )

    validate_schema('topology_old', topology_old)
    validate_schema('topology_new', topology_new)
    validate_consistency(topology_new)
    validate_availability(topology_new)
    validate_upgrade(topology_new, topology_old)

    return true
end

local function get_myself_uuids(topology)
    checks('?table')
    if topology == nil or topology.servers == nil then
        return nil, nil
    end

    local advertise_uri = membership.myself().uri
    for _it, instance_uuid, server in fun.filter(not_expelled, topology.servers) do
        if server.uri == advertise_uri then
            return instance_uuid, server.replicaset_uuid
        end
    end

    return nil, nil
end

local function cluster_is_healthy()
    if next(vars.topology.servers) == nil then
        return nil, 'not bootstrapped yet'
    end

    for _it, instance_uuid, server in fun.filter(not_disabled, vars.topology.servers) do
        local member = membership.get_member(server.uri) or {}

        if (member.status ~= 'alive') then
            return nil, string.format(
                '%s status is %s',
                server.uri, member.status
            )
        elseif (member.payload.uuid ~= instance_uuid) then
            return nil, string.format(
                '%s uuid mismath: expected %s, have %s',
                server.uri, instance_uuid, member.payload.uuid
            )
        elseif (member.payload.error ~= nil) then
            return nil, string.format(
                '%s: %s',
                server.uri, member.payload.error
            )
        elseif (not member.payload.ready) then
            local err
            if member.payload.warning then
                err = string.format('%s not ready: %s', server.uri, member.payload.warning)
            else
                err = string.format('%s not ready yet', server.uri)
            end
            return nil, err
        end
    end

    return true
end

-- returns SHARDING table, which can be passed to
-- vshard.router.cfg{sharding = SHARDING} and
-- vshard.storage.cfg{sharding = SHARDING}
local function get_vshard_sharding_config()
    local sharding = {}
    local alive = {
        -- [instance_uuid] = true/false,
    }
    local min_alive_uuid = {
        -- [replicaset_uuid] = instance_uuid,
    }

    for _it, instance_uuid, server in fun.filter(not_disabled, vars.topology.servers) do
        local replicaset_uuid = server.replicaset_uuid
        local replicaset = vars.topology.replicasets[replicaset_uuid]
        if replicaset.roles['vshard-storage'] then
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
                master = false,
            }

            local member = membership.get_member(server.uri)
            if member == nil
            or member.status ~= 'alive'
            or member.payload.error then
                alive[instance_uuid] = false
            else
                alive[instance_uuid] = true
                if min_alive_uuid[replicaset_uuid] == nil
                or instance_uuid < min_alive_uuid[replicaset_uuid] then
                    min_alive_uuid[replicaset_uuid] = instance_uuid
                end
            end
        end
    end

    for replicaset_uuid, shard in pairs(sharding) do
        local master_uuid = vars.topology.replicasets[replicaset_uuid].master

        if vars.topology.failover
        and not alive[master_uuid]
        and min_alive_uuid[replicaset_uuid] then
            master_uuid = min_alive_uuid[replicaset_uuid]
        end

        shard.replicas[master_uuid].master = true
    end

    return sharding
end

local function get_replication_config(topology, replicaset_uuid)
    checks('?table', 'string')
    if topology == nil or topology.servers == nil then
        return {}
    end

    local replication = {}
    local advertise_uri = membership.myself().uri

    for _it, instance_uuid, server in fun.filter(not_disabled, topology.servers) do
        if server.replicaset_uuid == replicaset_uuid
        and server.uri ~= advertise_uri then
            table.insert(replication, pool.format_uri(server.uri))
        end
    end

    table.sort(replication)
    return replication
end

return {
    set = function(topology)
        checks('table')
        vars.topology = topology
    end,
    get = function()
        return table.deepcopy(vars.topology)
    end,
    validate = function(...)
        return e_config:pcall(validate, ...)
    end,
    add_known_role = function(role_name)
        vars.known_roles[role_name] = true
    end,

    not_expelled = not_expelled,
    not_disabled = not_disabled,

    cluster_is_healthy = cluster_is_healthy,
    get_myself_uuids = get_myself_uuids,
    get_replication_config = get_replication_config,
    get_vshard_sharding_config = get_vshard_sharding_config,
}
