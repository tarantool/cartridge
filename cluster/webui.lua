#!/usr/bin/env tarantool

local log = require('log')
local json = require('json').new()
local yaml = require('yaml').new()
local front = require('front')
local errors = require('errors')

json.cfg({
    encode_use_tostring = true,
})
yaml.cfg({
    encode_use_tostring = true,
})

local admin = require('cluster.admin')
local graphql = require('cluster.graphql')
local gql_types = require('cluster.graphql.types')
local confapplier = require('cluster.confapplier')
local front_bundle = require('cluster.front-bundle')

local statistics_schema = {
    kind = gql_types.object {
        name='ServerStat',
        desciprtion = 'Slab allocator statistics.' ..
            ' This can be used to monitor the total' ..
            ' memory usage and memory fragmentation.',
        fields={
            items_size = gql_types.long,
            items_used = gql_types.long,
            items_used_ratio = gql_types.string,

            quota_size = gql_types.long,
            quota_used = gql_types.long,
            quota_used_ratio = gql_types.string,

            arena_size = gql_types.long,
            arena_used = gql_types.long,
            arena_used_ratio = gql_types.string,
        }
    },
    arguments = {},
    description = 'Node statistics',
    resolve = function(root, _)
        return admin.get_stat(root.uri)
    end,
}

local gql_type_replicaset = gql_types.object {
    name = 'Replicaset',
    description = 'Group of servers replicating the same data',
    fields = {
        uuid = gql_types.string.nonNull,
        roles = gql_types.list(gql_types.string.nonNull),
        status = gql_types.string.nonNull,
        weight = gql_types.float,
        master = gql_types.nonNull('Server'),
        active_master = gql_types.nonNull('Server'),
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
        disabled = gql_types.boolean.nonNull,
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

local function http_finalize_error(http_code, err)
    log.error(tostring(err))
    return {
        status = http_code,
        headers = {
            ['content-type'] = "application/json",
        },
        body = json.encode(err),
    }
end

local download_error = errors.new_class('Config download failed')
local function download_config_handler(_)
    local conf = confapplier.get_deepcopy()
    if conf == nil then
        local err = download_error:new('Cluster isn\'t bootsrapped yet')
        return http_finalize_error(409, err)
    end

    conf.topology = nil
    conf.vshard = nil

    return {
        status = 200,
        headers = {
            ['content-type'] = "application/yaml",
            ['content-disposition'] = 'attachment; filename="config.yml"',
        },
        body = yaml.encode(conf)
    }
end

local upload_error = errors.new_class('Config upload failed')
local function upload_config_handler(req)
    if confapplier.get_readonly() == nil then
        local err = upload_error:new('Cluster isn\'t bootsrapped yet')
        return http_finalize_error(409, err)
    end

    local req_body = req:read()
    local content_type = req.headers['content-type']
    if content_type == nil then
        local err = upload_error:new('Content-Type must be specified')
        return http_finalize_error(400, err)
    end

    local multipart, boundary = content_type:match('(multipart/form%-data); boundary=(.+)')
    if multipart == 'multipart/form-data' then
        -- RFC 2046 http://www.ietf.org/rfc/rfc2046.txt
        -- 5.1.1.  Common Syntax
        -- The boundary delimiter line is then defined as a line
        -- consisting entirely of two hyphen characters ("-", decimal value 45)
        -- followed by the boundary parameter value from the Content-Type header
        -- field, optional linear whitespace, and a terminating CRLF.
        --
        -- string.match takes a pattern, thus we have to prefix any characters
        -- that have a special meaning with % to escape them.
        -- A list of special characters is ().+-*?[]^$%
        local boundary_line = string.gsub('--'..boundary, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
        local formdata_headers
        formdata_headers, req_body = req_body:match(
            boundary_line .. '\r\n' ..
            '(.-\r\n)' .. '\r\n' .. -- headers
            '(.-)' .. '\r\n' .. -- body
            boundary_line
        )
        content_type = formdata_headers:match('Content%-Type: (.-)\r\n')
    end


    local conf, err = nil
    if content_type == 'application/json' then
        conf, err = upload_error:pcall(json.decode, req_body)
    elseif content_type == 'application/yaml' then
        conf, err = upload_error:pcall(yaml.decode, req_body)
    elseif req_body == nil then
        err = upload_error:new('Request body must not be empty')
    else
        err = upload_error:new('Unsupported Content-Type: %q', content_type)
    end

    if err ~= nil then
        return http_finalize_error(400, err)
    elseif conf == nil then
        err = upload_error:new('Config must not be empty')
        return http_finalize_error(400, err)
    end

    log.warn('Config uploaded')

    local ok, err = confapplier.patch_clusterwide(conf)
    if ok == nil then
        return http_finalize_error(400, err)
    end

    return { status = 200 }

end

local function init(httpd)
    front.init(httpd)
    front.add('cluster', front_bundle)
    httpd:route({
        path = '/admin/config',
        method = 'PUT'
    }, upload_config_handler)
    httpd:route({
        path = '/admin/config',
        method = 'GET'
    }, download_config_handler)

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
            timeout = gql_types.float,
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
        name = 'expel_server',
        args = {
            uuid = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.expel_server',
    })

    graphql.add_mutation({
        name = 'edit_replicaset',
        args = {
            uuid = gql_types.string.nonNull,
            roles = gql_types.list(gql_types.string.nonNull),
            master = gql_types.string,
            weight = gql_types.float,
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

    graphql.add_callback({
        prefix = 'cluster',
        name = 'known_roles',
        doc = 'Get list of registered roles.',
        args = {},
        kind = gql_types.list(gql_types.string.nonNull),
        callback = 'cluster.webui.get_known_roles',
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

    graphql.add_mutation({
        prefix = 'cluster',
        name = 'disable_servers',
        doc = 'Disable listed servers by uuid',
        args = {
            uuids = gql_types.list(gql_types.string.nonNull),
        },
        kind = gql_types.list('Server'),
        callback = 'cluster.webui.disable_servers',
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

    graphql.add_callback({
        prefix = 'cluster',
        name = 'can_bootstrap_vshard',
        doc = 'Whether it is reasonble to call bootstrap_vshard mutation',
        args = {},
        kind = gql_types.boolean.nonNull,
        callback = 'cluster.webui.can_bootstrap_vshard',
    })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'vshard_bucket_count',
        doc = 'Virtual buckets count in cluster',
        args = {},
        kind = gql_types.int.nonNull,
        callback = 'cluster.webui.vshard_bucket_count',
    })

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
    expel_server = expel_server,
    disable_servers = disable_servers,

    get_known_roles = confapplier.get_known_roles,
    get_failover_enabled = get_failover_enabled,
    set_failover_enabled = set_failover_enabled,

    bootstrap_vshard = admin.bootstrap_vshard,
    vshard_bucket_count = admin.vshard_bucket_count,
    can_bootstrap_vshard = admin.can_bootstrap_vshard,
}
