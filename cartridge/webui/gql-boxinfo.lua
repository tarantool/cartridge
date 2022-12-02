local gql_types = require('graphql.types')
local lua_api_boxinfo = require('cartridge.lua-api.boxinfo')

local gql_type_error = gql_types.object({
    name = 'Error',
    fields = {
        message = gql_types.string.nonNull,
        class_name = gql_types.string,
        stack = gql_types.string,
    }
})

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
        downstream_lag = gql_types.float,
    },
})

local gql_vshard_router = gql_types.object({
    name = 'VshardRouter',
    fields = {
        vshard_group = {
            kind = gql_types.string,
            description = 'Vshard group',
        },
        buckets_available_ro = {
            kind = gql_types.int,
            description = 'The number of buckets known to the router' ..
                ' and available for read requests',
        },
        buckets_available_rw = {
            kind = gql_types.int,
            description = 'The number of buckets known to the router' ..
                ' and available for read and write requests',
        },
        buckets_unreachable = {
            kind = gql_types.int,
            description = 'The number of buckets known to the router' ..
                ' but unavailable for any requests',
        },
        buckets_unknown = {
            kind = gql_types.int,
            description = 'The number of buckets whose replica' ..
                ' sets are not known to the router',
        },
    }
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
                    app_version = {
                        kind = gql_types.string,
                        description = 'The Application version',
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
                    http_port = {
                        kind = gql_types.int,
                        description = 'HTTP port',
                    },
                    http_host = {
                        kind = gql_types.string,
                        description = 'HTTP host',
                    },
                    webui_prefix = {
                        kind = gql_types.string,
                        description = 'HTTP webui prefix',
                    },
                    ro = {
                        kind = gql_types.boolean.nonNull,
                        description = 'Current read-only state',
                    },
                    ro_reason = {
                        kind = gql_types.string,
                        description = 'Current read-only state reason',
                    },

                    election_state = {
                        kind = gql_types.string,
                        description = 'State after Raft leader election',
                    },
                    election_mode = {
                        kind = gql_types.string.nonNull,
                        description = 'Instance election mode',
                    },
                    synchro_queue_owner = {
                        kind = gql_types.int.nonNull,
                        description = 'Id of current queue owner',
                    },
                }
            }).nonNull,
            storage = gql_types.object({
                name = 'ServerInfoStorage',
                fields = {
                    -- wal
                    too_long_threshold = {
                        kind = gql_types.float,
                        description = 'Warning in the WAL log if a transaction waits for quota' ..
                            ' for more than `too_long_threshold` seconds',
                    },
                    wal_dir_rescan_delay = {
                        kind = gql_types.float,
                        description = 'Background fiber restart delay to follow xlog changes.',
                    },
                    wal_max_size = {
                        kind = gql_types.long,
                        description = 'The maximal size of a single write-ahead log file',
                    },
                    wal_queue_max_size = {
                        kind = gql_types.long,
                        description = 'Limit the pace at which replica submits new transactions to WAL',
                    },
                    wal_cleanup_delay = {
                        kind = gql_types.long,
                        description = 'Option to prevent early cleanup of `*.xlog` files' ..
                            ' which are needed by replicas and lead to `XlogGapError`',
                    },
                    wal_mode = {
                        kind = gql_types.string,
                        description =
                            'Specify fiber-WAL-disk synchronization mode as:' ..
                            ' "none": write-ahead log is not maintained;' ..
                            ' "write": fibers wait for their data to be written to the write-ahead log;' ..
                            ' "fsync": fibers wait for their data, fsync follows each write.',
                    },
                    rows_per_wal = {
                        kind = gql_types.long,
                        description = 'Deprecated. See "wal_max_size"',
                    },

                    -- memtx
                    memtx_memory = {
                        kind = gql_types.long,
                        description = 'How much memory Memtx engine allocates to actually store tuples, in bytes.',
                    },
                    memtx_allocator = {
                        kind = gql_types.string,
                        description = 'Allows to select the appropriate allocator for memtx tuples if necessary.',
                    },
                    memtx_max_tuple_size = {
                        kind = gql_types.long,
                        description = 'Size of the largest allocation unit, in bytes.' ..
                            ' It can be tuned up if it is necessary to store large tuples.',
                    },
                    memtx_min_tuple_size = {
                        kind = gql_types.long,
                        description = 'Size of the smallest allocation unit, in bytes.' ..
                            ' It can be tuned up if most of the tuples are not so small.',
                    },

                    -- vinyl
                    vinyl_bloom_fpr = {
                        kind = gql_types.float,
                        description = 'Bloom filter false positive rate',
                    },
                    vinyl_cache = {
                        kind = gql_types.long,
                        description = 'The cache size for the vinyl storage engine',
                    },
                    vinyl_memory = {
                        kind = gql_types.long,
                        description = 'The maximum number of in-memory bytes that vinyl uses',
                    },
                    vinyl_max_tuple_size = {
                        kind = gql_types.long,
                        description = 'Size of the largest allocation unit, for the vinyl storage engine',
                    },
                    vinyl_page_size = {
                        kind = gql_types.long,
                        description = 'Page size. Page is a read/write unit for vinyl disk operations',
                    },
                    vinyl_range_size = {
                        kind = gql_types.long,
                        description = 'The default maximum range size for a vinyl index, in bytes',
                    },
                    vinyl_run_size_ratio = {
                        kind = gql_types.float,
                        description = 'Ratio between the sizes of different levels in the LSM tree',
                    },
                    vinyl_run_count_per_level = {
                        kind = gql_types.int,
                        description = 'The maximal number of runs per level in vinyl LSM tree',
                    },
                    vinyl_timeout = {
                        kind = gql_types.float,
                        description = 'Timeout between compactions',
                    },
                    vinyl_read_threads = {
                        kind = gql_types.int,
                        description = 'The maximum number of read threads that vinyl can use for some concurrent '..
                        'operations, such as I/O and compression',
                    },
                    vinyl_write_threads = {
                        kind = gql_types.int,
                        description = 'The maximum number of write threads that vinyl can use for some concurrent ' ..
                        'operations, such as I/O and compression',
                    },
                },
            }).nonNull,
            network = gql_types.object({
                name = 'ServerInfoNetwork',
                fields = {
                    net_msg_max = {
                        kind = gql_types.long,
                        description = 'Since if the net_msg_max limit is reached,' ..
                            ' we will stop processing incoming requests',
                    },
                    readahead = {
                        kind = gql_types.long,
                        description = 'The size of the read-ahead buffer associated with a client connection',
                    },
                    io_collect_interval = {
                        kind = gql_types.float,
                        description = 'The server will sleep for `io_collect_interval` seconds' ..
                            ' between iterations of the event loop',
                    },
                },
            }).nonNull,
            replication = gql_types.object({
                name = 'ServerInfoReplication',
                fields = {
                    replication_connect_quorum = {
                        kind = gql_types.int,
                        description =
                            'Minimal number of replicas to sync for this instance to switch' ..
                            ' to the write mode. If set to REPLICATION_CONNECT_QUORUM_ALL,' ..
                            ' wait for all configured masters.',
                    },
                    replication_connect_timeout = {
                        kind = gql_types.float,
                        description =
                            'Maximal time box.cfg() may wait for connections to all configured' ..
                            ' replicas to be established. If box.cfg() fails to connect to all' ..
                            ' replicas within the timeout, it will either leave the instance in' ..
                            ' the orphan mode (recovery) or fail (bootstrap, reconfiguration).',
                    },
                    replication_skip_conflict = {
                        kind = gql_types.boolean,
                        description = 'Allows automatic skip of conflicting rows in replication' ..
                            ' based on box.cfg configuration option.',
                    },
                    replication_sync_lag = {
                        kind = gql_types.float,
                        description = 'Switch applier from "sync" to "follow" as soon as the replication' ..
                            ' lag is less than the value of the following variable.',
                    },
                    replication_sync_timeout = {
                        kind = gql_types.float,
                        description = 'Max time to wait for appliers to synchronize before entering the orphan mode.',
                    },
                    replication_timeout = {
                        kind = gql_types.float,
                        description = 'Wait for the given period of time before trying to reconnect to a master.',
                    },
                    replication_threads = {
                        kind = gql_types.float,
                        description = 'How many threads to use for decoding incoming replication stream.',
                    },
                    vclock = {
                        kind = gql_types.list(gql_types.long),
                        description =
                            'The vector clock of' ..
                            ' replication log sequence numbers',
                    },
                    replication_info = {
                        kind = gql_types.list(gql_replica_status),
                        description =
                            'Statistics for all instances' ..
                            ' in the replica set in regard to the' ..
                            ' current instance',
                    },
                }
            }).nonNull,
            cartridge = gql_types.object({
                name = 'ServerInfoCartridge',
                fields = {
                    version = {
                        kind = gql_types.string.nonNull,
                        description = 'Cartridge version',
                    },
                    state = {
                        kind = gql_types.string.nonNull,
                        description = 'Current instance state',
                    },
                    error = {
                        kind = gql_type_error,
                        description =
                            'Error details if instance is in' ..
                            ' failure state',
                    }
                }
            }).nonNull,
            membership = gql_types.object({
                name = 'ServerInfoMembership',
                fields = {
                    status = {
                        kind = gql_types.string,
                        description = 'Status of the instance',
                    },
                    incarnation = {
                        kind = gql_types.int,
                        description = 'Value incremented every time the instance ' ..
                            'became a suspect, dead, or updates its payload',
                    },
                    PROTOCOL_PERIOD_SECONDS = {
                        kind = gql_types.float,
                        description = 'Direct ping period',
                    },
                    ACK_TIMEOUT_SECONDS = {
                        kind = gql_types.float,
                        description = 'ACK message wait time',
                    },
                    ANTI_ENTROPY_PERIOD_SECONDS = {
                        kind = gql_types.float,
                        description = 'Anti-entropy synchronization period',
                    },
                    SUSPECT_TIMEOUT_SECONDS = {
                        kind = gql_types.float,
                        description = 'Timeout to mark a suspect dead',
                    },
                    NUM_FAILURE_DETECTION_SUBGROUPS = {
                        kind = gql_types.int,
                        description = 'Number of members to ping a suspect indirectly',
                    },
                }
            }).nonNull,
            vshard_router = {
                kind = gql_types.list(gql_vshard_router),
                description = 'List of vshard router parameters',
            },
            vshard_storage = gql_types.object({
                name = 'ServerInfoVshardStorage',
                fields = {
                    vshard_group = {
                        kind = gql_types.string,
                        description = 'Vshard group',
                    },
                    buckets_receiving = {
                        kind = gql_types.int,
                        description = 'The number of buckets that are receiving at this time',
                    },
                    buckets_active = {
                        kind = gql_types.int,
                        description = 'The number of active buckets on the storage',
                    },
                    buckets_total = {
                        kind = gql_types.int,
                        description = 'Total number of buckets on the storage',
                    },
                    buckets_garbage = {
                        kind = gql_types.int,
                        description = 'The number of buckets that are waiting to be collected by GC',
                    },
                    buckets_pinned = {
                        kind = gql_types.int,
                        description = 'The number of pinned buckets on the storage',
                    },
                    buckets_sending = {
                        kind = gql_types.int,
                        description = 'The number of buckets that are sending at this time',
                    },
                }
            }),
        }
    }),
    arguments = {},
    resolve = function(root, _)
        return lua_api_boxinfo.get_info(root.uri), nil
    end,
}

return {
    schema = boxinfo_schema,
}
