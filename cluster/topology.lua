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
vars:new('topology', {
    servers = {
        -- ['instance-uuid-1'] = 'expelled',
        -- ['instance-uuid-2'] = {
        --     uri = 'localhost:3301',
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
        --     master_uuid = 'instance-uuid-2',
        -- }
    },
})

-- to be used in fun.filter
local function not_expelled(uuid, srv)
    return srv ~= 'expelled'
end

local function is_expelled(uuid, srv)
    return srv == 'expelled'
end

local function is_storage(uuid, srv)
    if srv == 'expelled' then
        return false
    end
    return utils.table_find(srv.roles, 'vshard-storage')
end

local function validate_schema(field, topology)
    checks('string', 'table')
    local servers = topology.servers or {}
    local replicasets = topology.replicasets or {}

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
                type(server.replicaset_uuid) == 'string',
                '%s.replicaset_uuid must be a string, got %s', field, type(server.replicaset_uuid)
            )
            e_config:assert(
                checkers.uuid_str(server.replicaset_uuid),
                '%s.replicaset_uuid %q is not a valid UUID', field, server.replicaset_uuid
            )

            local known_keys = {
                ['uri'] = true,
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
        }
        for k, v in pairs(replicaset) do
            e_config:assert(
                known_keys[k],
                '%s has unknown parameter %q', field, k
            )
        end
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

        local known_roles = {
            ['vshard-router'] = true,
            ['vshard-storage'] = true,
        }
        for role, _ in pairs(replicaset.roles) do
            e_config:assert(
                known_roles[role],
                '%s unknown role %q', field, tostring(role)
            )
        end
    end
end


local function validate_availability(topology)
    checks('table')
    local servers = topology.servers or {}

    for _it, instance_uuid, server in fun.filter(not_expelled, servers) do
        local member = membership.get_member(server.uri)
        e_config:assert(
            member ~= nil,
            'server %q is not in membership', server.uri
        )
        e_config:assert(
            member.status == 'alive',
            'server %q is unreachable with status %q',
            server.uri, member.status
        )
        e_config:assert(
            (member.payload.uuid == nil) or (member.payload.uuid == instance_uuid),
            'server %q bootstrapped with different uuid %q',
            server.uri, member.payload.uuid
        )
        e_config:assert(
            member.payload.error == nil,
            'server %q has error: %s',
            server.uri, member.payload.error
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
                '%s is expelled', field
            )
            e_config:assert(
                server_old.replicaset_uuid == server_new.replicaset_uuid,
                '%s.replicaset_uuid can not be changed', field
            )
        end
    end

    for replicaset_uuid, replicaset_old in pairs(replicasets_old) do
        local replicaset_new = replicasets_new[replicaset_uuid]

        if replicaset_old.roles['vshard-storage'] then
            e_config:assert(
                replicaset_new ~= nil,
                'replicasets[%s] is a vshard-storage and can not be removed', replicaset_uuid
            )
            e_config:assert(
                replicaset_new.roles['vshard-storage'] == true,
                'replicasets[%s].roles vshard-storage can not be disabled', replicaset_uuid
            )
        end
    end
end


local function validate(topology_new, topology_old)
    checks('table', '?table')
    topology_old = topology_old or {}

    validate_schema('topology_old', topology_old)
    validate_schema('topology_new', topology_new)
    validate_consistency(topology_new)
    validate_availability(topology_new)
    validate_upgrade(topology_new, topology_old)

    return true
end

local function cluster_is_healthy()
    if next(vars.servers) == nil then
        return nil, 'not bootstrapped yet'
    end

    for _it, instance_uuid, server in fun.filter(not_expelled, vars.servers) do
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

local function get_sharding_config()
    local sharding = {}

    for _it, instance_uuid, server in fun.filter(is_storage, vars.servers) do
        local replicaset_uuid = server.replicaset_uuid
        if sharding[replicaset_uuid] == nil then
            sharding[replicaset_uuid] = {
                replicas = {},
                weight = 1,
            }
        end

        local member = membership.get_member(server.uri)
        if not member
        or member.status ~= 'alive'
        or member.payload.error ~= nil then
            -- ignore
        else
            sharding[replicaset_uuid].replicas[instance_uuid] = {
                name = server.uri,
                uri = pool.format_uri(server.uri),
            }
        end
    end

    for uid, replicaset in pairs(sharding) do
        local min_uuid = next(replicaset.replicas)
        for uuid, replica in pairs(replicaset.replicas) do
            replica.master = false
            if uuid < min_uuid then
                min_uuid = uuid
            end
        end
        if min_uuid ~= nil then
            replicaset.replicas[min_uuid].master = true
        else
            log.warn('Empty replicaset %s!', uid)
        end
    end

    return sharding
end

local function get_replication_config(replicaset_uuid)
    local replication = {}
    local advertise_uri = membership.myself().uri

    for _it, instance_uuid, server in fun.filter(not_expelled, vars.servers) do
        if server.replicaset_uuid == replicaset_uuid
        and server.uri ~= advertise_uri then
            table.insert(replication, pool.format_uri(server.uri))
        end
    end

    table.sort(replication)
    return replication
end

local function list_uri_with_enabled_role(role)
    checks('string')

    local ret = {}

    for _it, instance_uuid, server in fun.filter(not_expelled, vars.servers) do
        local member = membership.get_member(server.uri) or {}

        if (not utils.table_find(server.roles, role)) -- ignore members without role
            or (member.status ~= 'alive') -- ignore non-alive members
            or (member.payload.uuid ~= instance_uuid) -- ignore misconfigured members
            or (member.payload.error ~= nil) -- ignore misconfigured members
        then
            -- do nothing
        else
            table.insert(ret, server.uri)
        end
    end

    return ret
end


return {
    set = function(servers)
        checks('table')
        vars.servers = servers
    end,
    get = function()
        return table.deepcopy(vars.servers)
    end,
    validate = function(...)
        return e_config:pcall(validate, ...)
    end,

    not_expelled = not_expelled,

    cluster_is_healthy = cluster_is_healthy,
    get_sharding_config = get_sharding_config,
    get_replication_config = get_replication_config,

    list_uri_with_enabled_role = list_uri_with_enabled_role,
}
