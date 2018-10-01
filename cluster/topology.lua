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

vars:new('servers', {})
local e_config = errors.new_class('Invalid cluster topology config')

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

local function validate(servers_new, servers_old)
    checks('table', '?table')
    servers_old = servers_old or {}

    -- validate that nobody was removed from previous config
    for instance_uuid, server_old in pairs(servers_old) do
        e_config:assert(
            servers_new[instance_uuid],
            'servers[%s] can not be removed from config', instance_uuid
        )
    end

    for instance_uuid, server_new in pairs(servers_new) do
        e_config:assert(
            type(instance_uuid) == 'string',
            'servers must have string keys'
        )
        e_config:assert(
            checkers.uuid_str(instance_uuid),
            'servers key %q is not a valid UUID', instance_uuid
        )
    end

    local replicasets = {}
    local singletons = {}
    for _it, instance_uuid, server_new in fun.filter(not_expelled, servers_new) do
        local field = string.format('servers[%s]', instance_uuid)
        local server_old = servers_old[instance_uuid]

        e_config:assert(
            type(server_new) == 'table',
            '%s must be either a table or the string "expelled"', field
        )
        e_config:assert(
            type(server_new.uri) == 'string',
            '%s.uri must be a string, got %s', field, type(server_new.uri)
        )
        e_config:assert(
            type(server_new.roles) == 'table',
            '%s.roles must be a table, got %s', field, type(server_new.roles)
        )
        e_config:assert(
            type(server_new.replicaset_uuid) == 'string',
            '%s.replicaset_uuid must be a string, got %s',
            field, type(server_new.replicaset_uuid)
        )
        e_config:assert(
            checkers.uuid_str(server_new.replicaset_uuid),
            '%s.replicaset_uuid is not a valid UUID', field
        )

        local roles_enabled = {
            ['vshard-storage'] = false,
            ['vshard-router'] = false,
        }

        for i, role in pairs(server_new.roles) do
            e_config:assert(
                roles_enabled[role] ~= nil,
                '%s.roles[%s] unknown role %q', field, i, tostring(role)
            )
            e_config:assert(
                roles_enabled[role] == false,
                '%s.roles has duplicate roles %q', field, role
            )

            roles_enabled[role] = true
        end

        local replicaset = replicasets[server_new.replicaset_uuid]
        e_config:assert(
            not replicaset
            or utils.deepcmp(roles_enabled, replicaset.roles),
            '%s.roles differ from %s.roles within same replicaset',
            field, (replicaset or {}).field
        )
        replicasets[server_new.replicaset_uuid] = {
            field = field,
            roles = roles_enabled,
        }

        if server_old then
            e_config:assert(
                server_old ~= 'expelled',
                '%s is already expelled', field
            )
            e_config:assert(
                server_old.replicaset_uuid == server_new.replicaset_uuid,
                '%s.replicaset_uuid can not be changed', field
            )
            if utils.table_find(server_old.roles, 'vshard-storage') then
                e_config:assert(
                    roles_enabled['vshard-storage'],
                    '%s.roles vshard-storage can not be disabled', field
                )
            end
        end

        local member = membership.get_member(server_new.uri)
        e_config:assert(
            member ~= nil,
            '%s.uri %q is not in membership', field, server_new.uri
        )
        e_config:assert(
            member.status == 'alive',
            '%s.uri %q is unreachable with status %q',
            field, server_new.uri, member.status
        )
        if member.payload.uuid then
            e_config:assert(
                member.payload.uuid == instance_uuid,
                '%s.uri %q bootstrapped with different uuid %q',
                field, server_new.uri, member.payload.uuid
            )
        end
        e_config:assert(
            member.payload.error == nil,
            '%s.uri %q has error: %s',
            field, server_new.uri, member.payload.error
        )

        local known_keys = {
            ['uri'] = true,
            ['roles'] = true,
            ['replicaset_uuid'] = true,
        }
        for k, v in pairs(server_new) do
            e_config:assert(
                known_keys[k],
                '%s has unknown parameter %q', field, k
            )
        end
    end

    for _it, instance_uuid, server_new in fun.filter(is_expelled, servers_new) do
        local field = string.format('servers[%s]', instance_uuid)
        local server_old = servers_old[instance_uuid]

        if type(server_old) == 'table' then
            -- expelling now
            e_config:assert(
                not utils.table_find(server_old.roles, 'vshard-storage')
                or replicasets[server_old.replicaset_uuid] ~= nil,
                '%s is the last storage in replicaset and can not be expelled', field
            )
        end
    end

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
