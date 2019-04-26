#!/usr/bin/env tarantool

local admin = require('cluster.admin')
local gql_types = require('cluster.graphql.types')
local confapplier = require('cluster.confapplier')
local gql_boxinfo_schema = require('cluster.webui.gql-boxinfo').schema
local gql_stat_schema = require('cluster.webui.gql-stat').schema
local module_name = 'cluster.webui.api-topology'

local gql_type_replicaset = gql_types.object {
    name = 'Replicaset',
    description = 'Group of servers replicating the same data',
    fields = {
        uuid = {
            kind = gql_types.string.nonNull,
            description = 'The replica set uuid',
        },
        roles = {
            kind = gql_types.list(gql_types.string.nonNull),
            description = 'The role set enabled' ..
                ' on every instance in the replica set',
        },
        status = {
            kind = gql_types.string.nonNull,
            description = 'The replica set health.' ..
                ' It is "healthy" if all instances have status "healthy".' ..
                ' Otherwise "unhealthy".',
        },
        weight = {
            kind = gql_types.float,
            description = 'Vshard replica set weight.' ..
                ' Null for replica sets with vshard-storage role disabled.'
        },
        master = {
            kind = gql_types.nonNull('Server'),
            description = 'The leader according to the configuration.',
        },
        active_master = {
            kind = gql_types.nonNull('Server'),
            description = [[The active leader. It may differ from]] ..
                [[ "master" if failover is enabled and configured leader]] ..
                [[ isn't healthy.]]
        },
        servers = {
            kind = gql_types.list(gql_types.nonNull('Server')).nonNull,
            description = 'Servers in the replica set.'
        },
    }
}

local gql_type_server = gql_types.object {
    name = 'Server',
    description = 'A server participating in tarantool cluster',
    fields = {
        alias = gql_types.string,
        uri = gql_types.string.nonNull,
        uuid = gql_types.string.nonNull,
        status = gql_types.string.nonNull,
        message = gql_types.string.nonNull,
        disabled = gql_types.boolean.nonNull,
        priority = {
            kind = gql_types.int.nonNull,
            description = 'Failover priority within the replica set',
        },
        replicaset = gql_type_replicaset,
        statistics = gql_stat_schema,
        boxinfo = gql_boxinfo_schema,
    }
}

local function get_servers(_, args)
    return admin.get_servers(args.uuid)
end

local function get_replicasets(_, args)
    return admin.get_replicasets(args.uuid)
end

local function probe_server(_, args)
    return admin.probe_server(args.uri)
end

local function join_server(_, args)
    return admin.join_server(args)
end

local function edit_server(_, args)
    return admin.edit_server(args)
end

local function expel_server(_, args)
    return admin.expel_server(args.uuid)
end

local function disable_servers(_, args)
    return admin.disable_servers(args.uuids)
end

local function edit_replicaset(_, args)
    return admin.edit_replicaset(args)
end

local function get_failover_enabled(_, _)
    return admin.get_failover_enabled()
end

local function set_failover_enabled(_, args)
    return admin.set_failover_enabled(args.enabled)
end


local function init(graphql)

    graphql.add_callback({
        name = 'servers',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Server'),
        callback = module_name .. '.get_servers',
    })

    graphql.add_callback({
        name = 'replicasets',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Replicaset'),
        callback = module_name .. '.get_replicasets',
    })

    graphql.add_mutation({
        name = 'probe_server',
        args = {
            uri = gql_types.string.nonNull
        },
        kind = gql_types.boolean,
        callback = module_name .. '.probe_server',
    })

    graphql.add_mutation({
        name = 'join_server',
        args = {
            uri = gql_types.string.nonNull,
            instance_uuid = gql_types.string,
            replicaset_uuid = gql_types.string,
            roles = gql_types.list(gql_types.string.nonNull),
            timeout = gql_types.float,
        },
        kind = gql_types.boolean,
        callback = module_name .. '.join_server',
    })

    graphql.add_mutation({
        name = 'edit_server',
        args = {
            uuid = gql_types.string.nonNull,
            uri = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = module_name .. '.edit_server',
    })

    graphql.add_mutation({
        name = 'expel_server',
        args = {
            uuid = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = module_name .. '.expel_server',
    })

    graphql.add_mutation({
        name = 'edit_replicaset',
        args = {
            uuid = gql_types.string.nonNull,
            roles = gql_types.list(gql_types.string.nonNull),
            master = gql_types.list(gql_types.string.nonNull),
            weight = gql_types.float,
        },
        kind = gql_types.boolean,
        callback = module_name .. '.edit_replicaset',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Get current failover state.',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.get_failover_enabled',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'known_roles',
        doc = 'Get list of registered roles.',
        args = {},
        kind = gql_types.list(gql_types.string.nonNull),
        callback = module_name .. '.get_known_roles',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Enable or disable automatic failover. '
            .. 'Returns new state.',
        args = {
            enabled = gql_types.boolean.nonNull,
        },
        kind = gql_types.boolean.nonNull,
        callback = module_name .. '.set_failover_enabled',
    })

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'disable_servers',
        doc = 'Disable listed servers by uuid',
        args = {
            uuids = gql_types.list(gql_types.string.nonNull),
        },
        kind = gql_types.list('Server'),
        callback = module_name .. '.disable_servers',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'self',
        doc = 'Get current server',
        args = {},
        kind = gql_types.object({
            name = 'ServerShortInfo',
            description = 'A short server information',
            fields = {
                uri = gql_types.string.nonNull,
                uuid = gql_types.string,
                alias = gql_types.string,
            },
        }),
        callback = module_name .. '.get_self',
    })
end

return {
    init = init,
    gql_type_server = gql_type_server,
    gql_type_replicaset = gql_type_replicaset,

    get_self = admin.get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,

    probe_server = probe_server,
    join_server = join_server,
    edit_server = edit_server,
    edit_replicaset = edit_replicaset,
    expel_server = expel_server,
    disable_servers = disable_servers,

    get_known_roles = confapplier.get_known_roles,
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,
}
