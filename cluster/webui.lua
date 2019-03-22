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

local webui_users = require('cluster.webui.users')

local statistics_schema = {
    kind = gql_types.object({
        name = 'ServerStat',
        description = 'Slab allocator statistics.' ..
            ' This can be used to monitor the total' ..
            ' memory usage (in bytes) and memory fragmentation.',
        fields = {
            items_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The total amount of memory' ..
                    ' (including allocated, but currently free slabs)' ..
                    ' used only for tuples, no indexes',
            },
            items_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The efficient amount of memory' ..
                    ' (omitting allocated, but currently free slabs)' ..
                    ' used only for tuples, no indexes',
            },
            items_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= items_used / slab_count * slab_size' ..
                    ' (these are slabs used only for tuples, no indexes)',
            },

            quota_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The maximum amount of memory that the slab allocator' ..
                    ' can use for both tuples and indexes' ..
                    ' (as configured in the memtx_memory parameter)',
            },
            quota_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The amount of memory that is already distributed' ..
                    ' to the slab allocator',
            },
            quota_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= quota_used / quota_size',
            },

            arena_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The total memory used for tuples and indexes together' ..
                    ' (including allocated, but currently free slabs)',
            },
            arena_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The efficient memory used for storing' ..
                    ' tuples and indexes together' ..
                    ' (omitting allocated, but currently free slabs)',
            },
            arena_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= arena_used / arena_size',
            },
        }
    }),
    arguments = {},
    resolve = function(root, _)
        return admin.get_stat(root.uri)
    end,
}

local gql_replica_status = gql_types.object({
    name = 'ReplicaStatus',
    description = 'Statistics for an instance in the replica set.',
    fields = {
        id = gql_types.int,
        lsn = gql_types.long,
        uuid = gql_types.string.nonNull,
        upstream_status = gql_types.string,
        upstream_message = gql_types.string,
        upstream_idle = gql_types.float,
        upstream_peer = gql_types.string,
        upstream_lag = gql_types.float,
        downstream_status = gql_types.string,
        downstream_message = gql_types.string,
    },
})

local boxinfo_schema = {
    kind = gql_types.object({
        name = 'ServerInfo',
        description = 'Server information and configuration.',
        fields = {
            general = gql_types.object({
                name = 'ServerInfoGeneral',
                fields = {
                    version = {
                        kind = gql_types.string.nonNull,
                        description = 'The Tarantool version',
                    },
                    pid = {
                        kind = gql_types.int.nonNull,
                        description = 'The process ID',
                    },
                    uptime = {
                        kind = gql_types.float.nonNull,
                        description = 'The number of seconds since the instance started',
                    },
                    instance_uuid = {
                        kind = gql_types.string.nonNull,
                        description = 'A globally unique identifier of the instance',
                    },
                    replicaset_uuid = {
                        kind = gql_types.string.nonNull,
                        description = 'The UUID of the replica set',
                    },

                    work_dir = {
                        kind = gql_types.string,
                        description = 'Current working directory of a process',
                    },
                    memtx_dir = {
                        kind = gql_types.string,
                        description = 'A directory where memtx stores snapshot (.snap) files',
                    },
                    vinyl_dir = {
                        kind = gql_types.string,
                        description = 'A directory where vinyl files or subdirectories will be stored',
                    },
                    wal_dir = {
                        kind = gql_types.string,
                        description = 'A directory where write-ahead log (.xlog) files are stored',
                    },
                    worker_pool_threads = {
                        kind = gql_types.int,
                        description =
                            'The maximum number of threads to use' ..
                            ' during execution of certain internal processes' ..
                            ' (currently socket.getaddrinfo() and coio_call())',
                    },


                    listen = {
                        kind = gql_types.string,
                        description = 'The binary protocol URI',
                    },
                    ro = {
                        kind = gql_types.boolean.nonNull,
                        description = 'Current read-only state',
                    },
                }
            }).nonNull,
            storage = gql_types.object({
                name = 'ServerInfoStorage',
                fields = {
                    -- wal
                    too_long_threshold = {
                        kind = gql_types.float,
                        description = '',
                    },
                    wal_dir_rescan_delay = {
                        kind = gql_types.float,
                        description = '',
                    },
                    wal_max_size = {
                        kind = gql_types.long,
                        description = '',
                    },
                    wal_mode = {
                        kind = gql_types.string,
                        description = '',
                    },
                    rows_per_wal = {
                        kind = gql_types.long,
                        description = '',
                    },

                    -- memtx
                    memtx_memory = {
                        kind = gql_types.long,
                        description = '',
                    },
                    memtx_max_tuple_size = {
                        kind = gql_types.long,
                        description = '',
                    },
                    memtx_min_tuple_size = {
                        kind = gql_types.long,
                        description = '',
                    },

                    -- vinyl
                    vinyl_bloom_fpr = gql_types.float,
                    vinyl_cache = gql_types.long,
                    vinyl_memory = gql_types.long,
                    vinyl_max_tuple_size = gql_types.long,
                    vinyl_page_size = gql_types.long,
                    vinyl_range_size = gql_types.long,
                    vinyl_run_size_ratio = gql_types.float,
                    vinyl_run_count_per_level = gql_types.int,
                    vinyl_timeout = gql_types.float,
                    vinyl_read_threads = gql_types.int,
                    vinyl_write_threads = gql_types.int,
                },
            }).nonNull,
            network = gql_types.object({
                name = 'ServerInfoNetwork',
                fields = {
                    net_msg_max = {
                        kind = gql_types.long,
                        description = '',
                    },
                    readahead = {
                        kind = gql_types.long,
                        description = '',
                    },
                    io_collect_interval = {
                        kind = gql_types.float,
                        description = '',
                    },
                },
            }).nonNull,
            replication = gql_types.object({
                name = 'ServerInfoReplication',
                fields = {
                    replication_connect_quorum = {
                        kind = gql_types.int,
                        description = '',
                    },
                    replication_connect_timeout = {
                        kind = gql_types.float,
                        description = '',
                    },
                    replication_skip_conflict = {
                        kind = gql_types.boolean,
                        description = '',
                    },
                    replication_sync_lag = {
                        kind = gql_types.float,
                        description = '',
                    },
                    replication_sync_timeout = {
                        kind = gql_types.float,
                        description = '',
                    },
                    replication_timeout = {
                        kind = gql_types.float,
                        description = '',
                    },
                    vclock = {
                        kind = gql_types.list(gql_types.long),
                        description =
                            'The vector clock of' ..
                            ' replication log sequence numbers',
                    },
                    replication_info = {
                        kind = gql_types.list(gql_replica_status.nonNull),
                        description =
                            'Statistics for all instances' ..
                            ' in the replica set in regard to the' ..
                            ' current instance',
                    },
                }
            }).nonNull,
        }
    }),
    arguments = {},
    resolve = function(root, _)
        return admin.get_info(root.uri)
    end,
}

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
            description = 'The active leader. It may differ from' ..
                ' "master" if failover is enabled and configured leader' ..
                ' isn\'t healthy.'
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
        boxinfo = boxinfo_schema,
        statistics = statistics_schema,
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

local e_upload = errors.new_class('Config upload failed')
local e_decode_yaml = errors.new_class('Decoding YAML failed')
local function upload_config_handler(req)
    if confapplier.get_readonly() == nil then
        local err = e_upload:new('Cluster isn\'t bootsrapped yet')
        return http_finalize_error(409, err)
    end

    local req_body = req:read()
    local content_type = req.headers['content-type'] or ''
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
        local _, form_body = req_body:match(
            boundary_line .. '\r\n' ..
            '(.-\r\n)' .. '\r\n' .. -- headers
            '(.-)' .. '\r\n' .. -- body
            boundary_line
        )
        req_body = form_body
    end


    local conf, err = nil
    if req_body == nil then
        err = e_upload:new('Request body must not be empty')
    else
        conf, err = e_decode_yaml:pcall(yaml.decode, req_body)
    end

    if err ~= nil then
        return http_finalize_error(400, err)
    elseif type(conf) ~= 'table' then
        err = e_upload:new('Config must be a table')
        return http_finalize_error(400, err)
    elseif next(conf) == nil then
        err = e_upload:new('Config must not be empty')
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

    -- User management
    webui_users.init()

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
            master = gql_types.list(gql_types.string.nonNull),
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
