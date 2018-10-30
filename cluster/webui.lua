#!/usr/bin/env tarantool

local log = require('log')
local fun = require('fun')
local fio = require('fio')
local json = require('json')
local yaml = require('yaml').new()
local errors = require('errors')
local uuid_lib = require('uuid')
local membership = require('membership')

local admin = require('cluster.admin')
local static = require('cluster.webui-static')
local graphql = require('cluster.graphql')
local gql_types = require('cluster.graphql.types')

yaml.cfg({
    encode_use_tostring = true
})

local statistics_schema = {
    kind = gql_types.object {
        name='ServerStat',
        desciprtion = 'Slab allocator statistics.' ..
            ' This can be used to monitor the total' ..
            ' memory usage and memory fragmentation.',
        fields={
            items_size = gql_types.long,
            items_used_ratio = gql_types.string,
            quota_size = gql_types.long,
            quota_used_ratio = gql_types.string,
            arena_used_ratio = gql_types.string,
            items_used = gql_types.long,
            quota_used = gql_types.long,
            arena_size = gql_types.long,
            arena_used = gql_types.long,
        }
    },
    arguments = {},
    description = 'Node statistics',
    resolve = function(self, args)
        -- TODO stat.graphql_stat,
        return {}
    end,
}

local gql_type_replicaset = gql_types.object {
    name = 'Replicaset',
    description = 'Group of servers replicating the same data',
    fields = {
        uuid = gql_types.string.nonNull,
        roles = gql_types.list(gql_types.string.nonNull),
        status = gql_types.string.nonNull,
        master = gql_types.nonNull('Server'),
        servers = gql_types.list('Server'),
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
        statistics = statistics_schema,
        replicaset = gql_type_replicaset,
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

local function bootstrap_vshard(_, args)
    return admin.bootstrap_vshard()
end

local function join_server(_, args)
    return admin.join_server(args)
end

local function edit_server(_, args)
    return admin.edit_server(args)
end

local function expell_server(_, args)
    return admin.expell_server(args.uuid)
end

local function edit_replicaset(_, args)
    return admin.edit_replicaset(args)
end

local function get_failover_enabled(_, args)
    return admin.get_failover_enabled()
end

local function set_failover_enabled(_, args)
    return admin.set_failover_enabled(args.enabled)
end

local function file_mime_type(filename)
    if string.endswith(filename, ".css") then
        return "text/css; charset=utf-8"
    elseif string.endswith(filename, ".js") then
        return "application/javascript; charset=utf-8"
    elseif string.endswith(filename, ".html") then
        return "text/html; charset=utf-8"
    elseif string.endswith(filename, ".jpeg") then
        return "image/jpeg"
    elseif string.endswith(filename, ".jpg") then
        return "image/jpeg"
    elseif string.endswith(filename, ".gif") then
        return "image/gif"
    elseif string.endswith(filename, ".png") then
        return "image/png"
    elseif string.endswith(filename, ".svg") then
        return "image/svg+xml"
    elseif string.endswith(filename, ".ico") then
        return "image/x-icon"
    elseif string.endswith(filename, "manifest.json") then
        return "application/manifest+json"
    end

    return "application/octet-stream"
end

local function render_file(path)
    local body = static[path]

    if body == nil then
        return {
            status = 404,
            body = string.format('File does not exist: %q', path)
        }
    end

    return {
        status = 200,
        headers = {
            ['content-type'] = file_mime_type(path)
        },
        body = body,
    }
end

local function init(httpd)
    graphql.init(httpd)
    graphql.add_mutation_prefix('cluster', 'Cluster management')
    graphql.add_callback_prefix('cluster', 'Cluster management')

    graphql.add_callback({
        name = 'servers',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Server'),
        callback = 'cluster.webui.get_servers',
    })

    graphql.add_callback({
        name = 'replicasets',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Replicaset'),
        callback = 'cluster.webui.get_replicasets',
    })

    graphql.add_mutation({
        name = 'probe_server',
        args = {
            uri = gql_types.string.nonNull
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.probe_server',
    })

    graphql.add_mutation({
        name = 'bootstrap_vshard',
        args = {},
        kind = gql_types.boolean,
        callback = 'cluster.webui.bootstrap_vshard',
    })

    graphql.add_mutation({
        name = 'join_server',
        args = {
            uri = gql_types.string.nonNull,
            instance_uuid = gql_types.string,
            replicaset_uuid = gql_types.string,
            roles = gql_types.list(gql_types.string.nonNull),
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.join_server',
    })

    graphql.add_mutation({
        name = 'edit_server',
        args = {
            uuid = gql_types.string.nonNull,
            uri = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.edit_server',
    })

    graphql.add_mutation({
        name = 'expell_server',
        args = {
            uuid = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.expell_server',
    })

    graphql.add_mutation({
        name = 'edit_replicaset',
        args = {
            uuid = gql_types.string.nonNull,
            roles = gql_types.list(gql_types.string.nonNull),
            master = gql_types.string,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.edit_replicaset',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'failover',
        doc = 'Get current failover state.',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = 'cluster.webui.get_failover_enabled',
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
        callback = 'cluster.webui.set_failover_enabled',
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
        callback = 'cluster.webui.get_self',
    })

    httpd:route({
            method = 'GET',
            path = '/',
            public = true,
        },
        function(req)
            return render_file('/index.html')
        end
    )
    httpd:route({
            method = 'GET',
            path = '/index.html',
            public = true,
        },
        function(req)
            return { status = 404, body = '404 Not Found' }
        end
    )

    -- Paths w/o dot are treated as app routes
    httpd:route({
            method = 'GET',
            path = '/[^.]*',
            public = true,
        },
        function(req)
            return render_file('/index.html')
        end
    )

    -- All other paths are treaded as file paths
    httpd:route({
            method = 'GET',
            path = '/.*',
            public = true,
        },
        function(req)
            return render_file(req.path)
        end
    )

    return true
end

return {
    init = init,

    get_self = admin.get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,

    probe_server = probe_server,
    join_server = join_server,
    edit_server = edit_server,
    edit_replicaset = edit_replicaset,
    expell_server = expell_server,

    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,

    bootstrap_vshard = bootstrap_vshard,
}
