/* @flow */

/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: string,
  String: string,
  Boolean: boolean,
  Int: number,
  Float: number,
  /** The `Long` scalar type represents non-fractional signed whole numeric values.
   * Long can represent values from -(2^52) to 2^52 - 1, inclusive.
   */
  Long: number
};

/** Cluster management */
export type Apicluster = {
  /** Get list of all registered roles and their dependencies. */
  known_roles: Array<Role>,
  /** Get current server */
  self?: ?ServerShortInfo,
  /** Get list of known vshard storage groups. */
  vshard_known_groups: Array<$ElementType<Scalars, "String">>,
  /** Get current failover state. */
  failover: $ElementType<Scalars, "Boolean">,
  /** Whether it is reasonble to call bootstrap_vshard mutation */
  can_bootstrap_vshard: $ElementType<Scalars, "Boolean">,
  /** Virtual buckets count in cluster */
  vshard_bucket_count: $ElementType<Scalars, "Int">,
  auth_params: UserManagementApi,
  /** List authorized users */
  users?: ?Array<User>
};

/** Cluster management */
export type ApiclusterUsersArgs = {
  username?: ?$ElementType<Scalars, "String">
};

/** Cluster server label */
export type Label = {
  name: $ElementType<Scalars, "String">,
  value: $ElementType<Scalars, "String">
};

/** Cluster server label */
export type LabelInput = {
  name: $ElementType<Scalars, "String">,
  value: $ElementType<Scalars, "String">
};

export type Mutation = {
  /** Cluster management */
  cluster?: ?MutationApicluster,
  edit_server?: ?$ElementType<Scalars, "Boolean">,
  probe_server?: ?$ElementType<Scalars, "Boolean">,
  edit_replicaset?: ?$ElementType<Scalars, "Boolean">,
  join_server?: ?$ElementType<Scalars, "Boolean">,
  bootstrap_vshard?: ?$ElementType<Scalars, "Boolean">,
  expel_server?: ?$ElementType<Scalars, "Boolean">
};

export type MutationEdit_ServerArgs = {
  uuid: $ElementType<Scalars, "String">,
  uri?: ?$ElementType<Scalars, "String">,
  labels?: ?Array<?LabelInput>
};

export type MutationProbe_ServerArgs = {
  uri: $ElementType<Scalars, "String">
};

export type MutationEdit_ReplicasetArgs = {
  weight?: ?$ElementType<Scalars, "Float">,
  master?: ?Array<$ElementType<Scalars, "String">>,
  roles?: ?Array<$ElementType<Scalars, "String">>,
  uuid: $ElementType<Scalars, "String">,
  vshard_group?: ?$ElementType<Scalars, "String">
};

export type MutationJoin_ServerArgs = {
  replicaset_uuid?: ?$ElementType<Scalars, "String">,
  uri: $ElementType<Scalars, "String">,
  labels?: ?Array<?LabelInput>,
  roles?: ?Array<$ElementType<Scalars, "String">>,
  instance_uuid?: ?$ElementType<Scalars, "String">,
  timeout?: ?$ElementType<Scalars, "Float">,
  vshard_group?: ?$ElementType<Scalars, "String">
};

export type MutationExpel_ServerArgs = {
  uuid: $ElementType<Scalars, "String">
};

/** Cluster management */
export type MutationApicluster = {
  auth_params: UserManagementApi,
  /** Remove user */
  remove_user?: ?User,
  /** Edit an existing user */
  edit_user?: ?User,
  /** Enable or disable automatic failover. Returns new state. */
  failover: $ElementType<Scalars, "Boolean">,
  /** Create a new user */
  add_user?: ?User,
  /** Disable listed servers by uuid */
  disable_servers?: ?Array<?Server>
};

/** Cluster management */
export type MutationApiclusterAuth_ParamsArgs = {
  enabled?: ?$ElementType<Scalars, "Boolean">
};

/** Cluster management */
export type MutationApiclusterRemove_UserArgs = {
  username: $ElementType<Scalars, "String">
};

/** Cluster management */
export type MutationApiclusterEdit_UserArgs = {
  password?: ?$ElementType<Scalars, "String">,
  username: $ElementType<Scalars, "String">,
  fullname?: ?$ElementType<Scalars, "String">,
  email?: ?$ElementType<Scalars, "String">
};

/** Cluster management */
export type MutationApiclusterFailoverArgs = {
  enabled: $ElementType<Scalars, "Boolean">
};

/** Cluster management */
export type MutationApiclusterAdd_UserArgs = {
  password: $ElementType<Scalars, "String">,
  username: $ElementType<Scalars, "String">,
  fullname?: ?$ElementType<Scalars, "String">,
  email?: ?$ElementType<Scalars, "String">
};

/** Cluster management */
export type MutationApiclusterDisable_ServersArgs = {
  uuids?: ?Array<$ElementType<Scalars, "String">>
};

export type Query = {
  /** Cluster management */
  cluster?: ?Apicluster,
  servers?: ?Array<?Server>,
  replicasets?: ?Array<?Replicaset>
};

export type QueryServersArgs = {
  uuid?: ?$ElementType<Scalars, "String">
};

export type QueryReplicasetsArgs = {
  uuid?: ?$ElementType<Scalars, "String">
};

/** Group of servers replicating the same data */
export type Replicaset = {
  /** The role set enabled on every instance in the replica set */
  roles?: ?Array<$ElementType<Scalars, "String">>,
  /** The active leader. It may differ from "master" if failover is enabled and configured leader isn't healthy. */
  active_master: Server,
  /** Vshard storage group name. Meaningful only when multiple vshard groups are configured. */
  vshard_group?: ?$ElementType<Scalars, "String">,
  /** The replica set uuid */
  uuid: $ElementType<Scalars, "String">,
  /** The replica set health. It is "healthy" if all instances have status "healthy". Otherwise "unhealthy". */
  status: $ElementType<Scalars, "String">,
  /** The leader according to the configuration. */
  master: Server,
  /** Servers in the replica set. */
  servers: Array<Server>,
  /** Vshard replica set weight. Null for replica sets with vshard-storage role disabled. */
  weight?: ?$ElementType<Scalars, "Float">
};

/** Statistics for an instance in the replica set. */
export type ReplicaStatus = {
  downstream_status?: ?$ElementType<Scalars, "String">,
  id?: ?$ElementType<Scalars, "Int">,
  upstream_peer?: ?$ElementType<Scalars, "String">,
  upstream_idle?: ?$ElementType<Scalars, "Float">,
  upstream_message?: ?$ElementType<Scalars, "String">,
  lsn?: ?$ElementType<Scalars, "Long">,
  upstream_lag?: ?$ElementType<Scalars, "Float">,
  upstream_status?: ?$ElementType<Scalars, "String">,
  uuid: $ElementType<Scalars, "String">,
  downstream_message?: ?$ElementType<Scalars, "String">
};

export type Role = {
  name: $ElementType<Scalars, "String">,
  dependencies?: ?Array<$ElementType<Scalars, "String">>
};

/** A server participating in tarantool cluster */
export type Server = {
  statistics?: ?ServerStat,
  boxinfo?: ?ServerInfo,
  status: $ElementType<Scalars, "String">,
  uuid: $ElementType<Scalars, "String">,
  replicaset?: ?Replicaset,
  uri: $ElementType<Scalars, "String">,
  alias?: ?$ElementType<Scalars, "String">,
  disabled?: ?$ElementType<Scalars, "Boolean">,
  message: $ElementType<Scalars, "String">,
  /** Failover priority within the replica set */
  priority?: ?$ElementType<Scalars, "Int">,
  labels?: ?Array<?Label>
};

/** Server information and configuration. */
export type ServerInfo = {
  network: ServerInfoNetwork,
  general: ServerInfoGeneral,
  replication: ServerInfoReplication,
  storage: ServerInfoStorage
};

export type ServerInfoGeneral = {
  /** A globally unique identifier of the instance */
  instance_uuid: $ElementType<Scalars, "String">,
  /** Current read-only state */
  ro: $ElementType<Scalars, "Boolean">,
  /** A directory where vinyl files or subdirectories will be stored */
  vinyl_dir?: ?$ElementType<Scalars, "String">,
  /** The maximum number of threads to use during execution of certain internal
   * processes (currently socket.getaddrinfo() and coio_call())
   */
  worker_pool_threads?: ?$ElementType<Scalars, "Int">,
  /** Current working directory of a process */
  work_dir?: ?$ElementType<Scalars, "String">,
  /** The number of seconds since the instance started */
  uptime: $ElementType<Scalars, "Float">,
  /** A directory where write-ahead log (.xlog) files are stored */
  wal_dir?: ?$ElementType<Scalars, "String">,
  /** The Tarantool version */
  version: $ElementType<Scalars, "String">,
  /** The binary protocol URI */
  listen?: ?$ElementType<Scalars, "String">,
  /** The process ID */
  pid: $ElementType<Scalars, "Int">,
  /** The UUID of the replica set */
  replicaset_uuid: $ElementType<Scalars, "String">,
  /** A directory where memtx stores snapshot (.snap) files */
  memtx_dir?: ?$ElementType<Scalars, "String">
};

export type ServerInfoNetwork = {
  io_collect_interval?: ?$ElementType<Scalars, "Float">,
  readahead?: ?$ElementType<Scalars, "Long">,
  net_msg_max?: ?$ElementType<Scalars, "Long">
};

export type ServerInfoReplication = {
  replication_connect_quorum?: ?$ElementType<Scalars, "Int">,
  replication_connect_timeout?: ?$ElementType<Scalars, "Float">,
  replication_sync_timeout?: ?$ElementType<Scalars, "Float">,
  replication_skip_conflict?: ?$ElementType<Scalars, "Boolean">,
  replication_sync_lag?: ?$ElementType<Scalars, "Float">,
  /** Statistics for all instances in the replica set in regard to the current instance */
  replication_info?: ?Array<ReplicaStatus>,
  /** The vector clock of replication log sequence numbers */
  vclock?: ?Array<?$ElementType<Scalars, "Long">>,
  replication_timeout?: ?$ElementType<Scalars, "Float">
};

export type ServerInfoStorage = {
  wal_max_size?: ?$ElementType<Scalars, "Long">,
  vinyl_run_count_per_level?: ?$ElementType<Scalars, "Int">,
  rows_per_wal?: ?$ElementType<Scalars, "Long">,
  vinyl_cache?: ?$ElementType<Scalars, "Long">,
  vinyl_range_size?: ?$ElementType<Scalars, "Long">,
  vinyl_timeout?: ?$ElementType<Scalars, "Float">,
  memtx_min_tuple_size?: ?$ElementType<Scalars, "Long">,
  vinyl_bloom_fpr?: ?$ElementType<Scalars, "Float">,
  vinyl_page_size?: ?$ElementType<Scalars, "Long">,
  memtx_max_tuple_size?: ?$ElementType<Scalars, "Long">,
  vinyl_run_size_ratio?: ?$ElementType<Scalars, "Float">,
  wal_mode?: ?$ElementType<Scalars, "String">,
  memtx_memory?: ?$ElementType<Scalars, "Long">,
  vinyl_memory?: ?$ElementType<Scalars, "Long">,
  too_long_threshold?: ?$ElementType<Scalars, "Float">,
  vinyl_max_tuple_size?: ?$ElementType<Scalars, "Long">,
  vinyl_write_threads?: ?$ElementType<Scalars, "Int">,
  vinyl_read_threads?: ?$ElementType<Scalars, "Int">,
  wal_dir_rescan_delay?: ?$ElementType<Scalars, "Float">
};

/** A short server information */
export type ServerShortInfo = {
  uri: $ElementType<Scalars, "String">,
  uuid?: ?$ElementType<Scalars, "String">,
  alias?: ?$ElementType<Scalars, "String">
};

/** Slab allocator statistics. This can be used to monitor the total memory usage (in bytes) and memory fragmentation. */
export type ServerStat = {
  /** The total amount of memory (including allocated, but currently free slabs) used only for tuples, no indexes */
  items_size: $ElementType<Scalars, "Long">,
  /** = items_used / slab_count * slab_size (these are slabs used only for tuples, no indexes) */
  items_used_ratio: $ElementType<Scalars, "String">,
  /** The maximum amount of memory that the slab allocator can use for both tuples
   * and indexes (as configured in the memtx_memory parameter)
   */
  quota_size: $ElementType<Scalars, "Long">,
  /** The amount of memory that is already distributed to the slab allocator */
  quota_used: $ElementType<Scalars, "Long">,
  /** = arena_used / arena_size */
  arena_used_ratio: $ElementType<Scalars, "String">,
  /** The efficient amount of memory (omitting allocated, but currently free slabs) used only for tuples, no indexes */
  items_used: $ElementType<Scalars, "Long">,
  /** = quota_used / quota_size */
  quota_used_ratio: $ElementType<Scalars, "String">,
  /** The total memory used for tuples and indexes together (including allocated, but currently free slabs) */
  arena_size: $ElementType<Scalars, "Long">,
  /** The efficient memory used for storing tuples and indexes together (omitting allocated, but currently free slabs) */
  arena_used: $ElementType<Scalars, "Long">
};

/** A single user account information */
export type User = {
  username: $ElementType<Scalars, "String">,
  fullname?: ?$ElementType<Scalars, "String">,
  email?: ?$ElementType<Scalars, "String">
};

/** User managent parameters and available operations */
export type UserManagementApi = {
  implements_remove_user: $ElementType<Scalars, "Boolean">,
  implements_add_user: $ElementType<Scalars, "Boolean">,
  implements_edit_user: $ElementType<Scalars, "Boolean">,
  /** Number of seconds until the authentication cookie expires. */
  cookie_max_age: $ElementType<Scalars, "Long">,
  /** Number of seconds to keep in cache cookie validation result. */
  cookie_caching_time: $ElementType<Scalars, "Long">,
  implements_list_users: $ElementType<Scalars, "Boolean">,
  implements_get_user: $ElementType<Scalars, "Boolean">,
  /** Whether authentication is enabled. */
  enabled: $ElementType<Scalars, "Boolean">,
  /** Active session username. */
  username?: ?$ElementType<Scalars, "String">,
  implements_check_password: $ElementType<Scalars, "Boolean">
};
type $Pick<Origin: Object, Keys: Object> = $ObjMapi<
  Keys,
  <Key>(k: Key) => $ElementType<Origin, Key>
>;

export type AuthQueryVariables = {};

export type AuthQuery = { __typename?: "Query" } & {
  cluster: ?({ __typename?: "Apicluster" } & {
    authParams: { __typename?: "UserManagementAPI" } & $Pick<
      UserManagementApi,
      { enabled: *, username: * }
    >
  })
};

export type TurnAuthMutationVariables = {
  enabled?: ?$ElementType<Scalars, "Boolean">
};

export type TurnAuthMutation = { __typename?: "Mutation" } & {
  cluster: ?({ __typename?: "MutationApicluster" } & {
    authParams: { __typename?: "UserManagementAPI" } & $Pick<
      UserManagementApi,
      { enabled: * }
    >
  })
};

export type GetClusterQueryVariables = {};

export type GetClusterQuery = { __typename?: "Query" } & {
  cluster: ?({ __typename?: "Apicluster" } & $Pick<
    Apicluster,
    {
      failover: *,
      can_bootstrap_vshard: *,
      vshard_bucket_count: *,
      vshard_known_groups: *
    }
  > & {
      clusterSelf: ?({ __typename?: "ServerShortInfo" } & {
        uri: $ElementType<ServerShortInfo, "uri">,
        uuid: $ElementType<ServerShortInfo, "uuid">
      }),
      knownRoles: Array<
        { __typename?: "Role" } & $Pick<Role, { name: *, dependencies: * }>
      >,
      authParams: { __typename?: "UserManagementAPI" } & $Pick<
        UserManagementApi,
        {
          enabled: *,
          implements_add_user: *,
          implements_check_password: *,
          implements_list_users: *,
          implements_edit_user: *,
          implements_remove_user: *,
          username: *
        }
      >
    })
};

export type BoxInfoQueryVariables = {
  uuid?: ?$ElementType<Scalars, "String">
};

export type BoxInfoQuery = { __typename?: "Query" } & {
  servers: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { alias: *, status: *, message: *, uri: * }
  > & {
      replicaset: ?({ __typename?: "Replicaset" } & $Pick<
        Replicaset,
        { roles: * }
      > & {
          active_master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
          master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>
        }),
      labels: ?Array<?({ __typename?: "Label" } & $Pick<
        Label,
        { name: *, value: * }
      >)>,
      boxinfo: ?({ __typename?: "ServerInfo" } & {
        network: { __typename?: "ServerInfoNetwork" } & $Pick<
          ServerInfoNetwork,
          { io_collect_interval: *, net_msg_max: *, readahead: * }
        >,
        general: { __typename?: "ServerInfoGeneral" } & $Pick<
          ServerInfoGeneral,
          { instance_uuid: *, uptime: *, version: *, ro: * }
        >,
        replication: { __typename?: "ServerInfoReplication" } & $Pick<
          ServerInfoReplication,
          {
            replication_connect_quorum: *,
            replication_connect_timeout: *,
            replication_sync_timeout: *,
            replication_skip_conflict: *,
            replication_sync_lag: *,
            vclock: *,
            replication_timeout: *
          }
        > & {
            replication_info: ?Array<
              { __typename?: "ReplicaStatus" } & $Pick<
                ReplicaStatus,
                {
                  downstream_status: *,
                  id: *,
                  upstream_peer: *,
                  upstream_idle: *,
                  upstream_message: *,
                  lsn: *,
                  upstream_lag: *,
                  upstream_status: *,
                  uuid: *,
                  downstream_message: *
                }
              >
            >
          },
        storage: { __typename?: "ServerInfoStorage" } & $Pick<
          ServerInfoStorage,
          {
            wal_max_size: *,
            vinyl_run_count_per_level: *,
            rows_per_wal: *,
            vinyl_cache: *,
            vinyl_range_size: *,
            vinyl_timeout: *,
            memtx_min_tuple_size: *,
            vinyl_bloom_fpr: *,
            vinyl_page_size: *,
            memtx_max_tuple_size: *,
            vinyl_run_size_ratio: *,
            wal_mode: *,
            memtx_memory: *,
            vinyl_memory: *,
            too_long_threshold: *,
            vinyl_max_tuple_size: *,
            vinyl_write_threads: *,
            vinyl_read_threads: *,
            wal_dir_rescan_delay: *
          }
        >
      })
    })>
};

export type InstanceDataQueryVariables = {
  uuid?: ?$ElementType<Scalars, "String">
};

export type InstanceDataQuery = { __typename?: "Query" } & {
  servers: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { alias: *, status: *, message: *, uri: * }
  > & {
      replicaset: ?({ __typename?: "Replicaset" } & $Pick<
        Replicaset,
        { roles: * }
      > & {
          active_master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
          master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>
        }),
      labels: ?Array<?({ __typename?: "Label" } & $Pick<
        Label,
        { name: *, value: * }
      >)>,
      boxinfo: ?({ __typename?: "ServerInfo" } & {
        network: { __typename?: "ServerInfoNetwork" } & $Pick<
          ServerInfoNetwork,
          { io_collect_interval: *, net_msg_max: *, readahead: * }
        >,
        general: { __typename?: "ServerInfoGeneral" } & $Pick<
          ServerInfoGeneral,
          { instance_uuid: *, uptime: *, version: *, ro: * }
        >,
        replication: { __typename?: "ServerInfoReplication" } & $Pick<
          ServerInfoReplication,
          {
            replication_connect_quorum: *,
            replication_connect_timeout: *,
            replication_sync_timeout: *,
            replication_skip_conflict: *,
            replication_sync_lag: *,
            vclock: *,
            replication_timeout: *
          }
        > & {
            replication_info: ?Array<
              { __typename?: "ReplicaStatus" } & $Pick<
                ReplicaStatus,
                {
                  downstream_status: *,
                  id: *,
                  upstream_peer: *,
                  upstream_idle: *,
                  upstream_message: *,
                  lsn: *,
                  upstream_lag: *,
                  upstream_status: *,
                  uuid: *,
                  downstream_message: *
                }
              >
            >
          },
        storage: { __typename?: "ServerInfoStorage" } & $Pick<
          ServerInfoStorage,
          {
            wal_max_size: *,
            vinyl_run_count_per_level: *,
            rows_per_wal: *,
            vinyl_cache: *,
            vinyl_range_size: *,
            vinyl_timeout: *,
            memtx_min_tuple_size: *,
            vinyl_bloom_fpr: *,
            vinyl_page_size: *,
            memtx_max_tuple_size: *,
            vinyl_run_size_ratio: *,
            wal_mode: *,
            memtx_memory: *,
            vinyl_memory: *,
            too_long_threshold: *,
            vinyl_max_tuple_size: *,
            vinyl_write_threads: *,
            vinyl_read_threads: *,
            wal_dir_rescan_delay: *
          }
        >
      })
    })>,
  descriptionGeneral: ?({ __typename?: "__Type" } & {
    fields: ?Array<
      { __typename?: "__Field" } & $Pick<__Field, { name: *, description: * }>
    >
  }),
  descriptionNetwork: ?({ __typename?: "__Type" } & {
    fields: ?Array<
      { __typename?: "__Field" } & $Pick<__Field, { name: *, description: * }>
    >
  }),
  descriptionReplication: ?({ __typename?: "__Type" } & {
    fields: ?Array<
      { __typename?: "__Field" } & $Pick<__Field, { name: *, description: * }>
    >
  }),
  descriptionStorage: ?({ __typename?: "__Type" } & {
    fields: ?Array<
      { __typename?: "__Field" } & $Pick<__Field, { name: *, description: * }>
    >
  })
};

export type PageQueryVariables = {};

export type PageQuery = { __typename?: "Query" } & {
  serverList: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: *, alias: *, uri: *, status: *, message: * }
  > & {
      replicaset: ?({ __typename?: "Replicaset" } & $Pick<
        Replicaset,
        { uuid: * }
      >)
    })>,
  replicasetList: ?Array<?({ __typename?: "Replicaset" } & $Pick<
    Replicaset,
    { uuid: *, status: *, roles: *, vshard_group: *, weight: * }
  > & {
      master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      active_master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      servers: Array<
        { __typename?: "Server" } & $Pick<
          Server,
          { uuid: *, alias: *, uri: *, status: *, message: * }
        > & {
            replicaset: ?({ __typename?: "Replicaset" } & $Pick<
              Replicaset,
              { uuid: * }
            >),
            labels: ?Array<?({ __typename?: "Label" } & $Pick<
              Label,
              { name: *, value: * }
            >)>
          }
      >
    })>,
  serverStat: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: * }
  > & {
      statistics: ?({ __typename?: "ServerStat" } & {
        quotaSize: $ElementType<ServerStat, "quota_size">,
        arenaUsed: $ElementType<ServerStat, "arena_used">
      })
    })>
};

export type ServerListQueryVariables = {};

export type ServerListQuery = { __typename?: "Query" } & {
  serverList: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: *, alias: *, uri: *, status: *, message: * }
  > & {
      replicaset: ?({ __typename?: "Replicaset" } & $Pick<
        Replicaset,
        { uuid: * }
      >)
    })>,
  replicasetList: ?Array<?({ __typename?: "Replicaset" } & $Pick<
    Replicaset,
    { uuid: *, status: *, roles: *, vshard_group: *, weight: * }
  > & {
      master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      active_master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      servers: Array<
        { __typename?: "Server" } & $Pick<
          Server,
          { uuid: *, alias: *, uri: *, status: *, message: * }
        > & {
            replicaset: ?({ __typename?: "Replicaset" } & $Pick<
              Replicaset,
              { uuid: * }
            >),
            labels: ?Array<?({ __typename?: "Label" } & $Pick<
              Label,
              { name: *, value: * }
            >)>
          }
      >
    })>,
  serverStat: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: *, uri: * }
  > & {
      statistics: ?({ __typename?: "ServerStat" } & {
        quotaSize: $ElementType<ServerStat, "quota_size">,
        arenaUsed: $ElementType<ServerStat, "arena_used">
      })
    })>
};

export type ServerListWithoutStatQueryVariables = {};

export type ServerListWithoutStatQuery = { __typename?: "Query" } & {
  serverList: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: *, alias: *, uri: *, status: *, message: * }
  > & {
      replicaset: ?({ __typename?: "Replicaset" } & $Pick<
        Replicaset,
        { uuid: * }
      >)
    })>,
  replicasetList: ?Array<?({ __typename?: "Replicaset" } & $Pick<
    Replicaset,
    { uuid: *, status: *, roles: *, vshard_group: *, weight: * }
  > & {
      master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      active_master: { __typename?: "Server" } & $Pick<Server, { uuid: * }>,
      servers: Array<
        { __typename?: "Server" } & $Pick<
          Server,
          { uuid: *, alias: *, uri: *, status: *, message: * }
        > & {
            replicaset: ?({ __typename?: "Replicaset" } & $Pick<
              Replicaset,
              { uuid: * }
            >),
            labels: ?Array<?({ __typename?: "Label" } & $Pick<
              Label,
              { name: *, value: * }
            >)>
          }
      >
    })>
};

export type ServerStatQueryVariables = {};

export type ServerStatQuery = { __typename?: "Query" } & {
  serverStat: ?Array<?({ __typename?: "Server" } & $Pick<
    Server,
    { uuid: *, uri: * }
  > & {
      statistics: ?({ __typename?: "ServerStat" } & {
        quotaSize: $ElementType<ServerStat, "quota_size">,
        arenaUsed: $ElementType<ServerStat, "arena_used">
      })
    })>
};

export type BootstrapMutationVariables = {};

export type BootstrapMutation = { __typename?: "Mutation" } & {
  bootstrapVshardResponse: $ElementType<Mutation, "bootstrap_vshard">
};

export type ProbeMutationVariables = {
  uri: $ElementType<Scalars, "String">
};

export type ProbeMutation = { __typename?: "Mutation" } & {
  probeServerResponse: $ElementType<Mutation, "probe_server">
};

export type JoinMutationVariables = {
  uri: $ElementType<Scalars, "String">,
  uuid: $ElementType<Scalars, "String">
};

export type JoinMutation = { __typename?: "Mutation" } & {
  joinServerResponse: $ElementType<Mutation, "join_server">
};

export type CreateReplicasetMutationVariables = {
  uri: $ElementType<Scalars, "String">,
  roles?: ?Array<$ElementType<Scalars, "String">>,
  vshard_group?: ?$ElementType<Scalars, "String">
};

export type CreateReplicasetMutation = { __typename?: "Mutation" } & {
  createReplicasetResponse: $ElementType<Mutation, "join_server">
};

export type ExpelMutationVariables = {
  uuid: $ElementType<Scalars, "String">
};

export type ExpelMutation = { __typename?: "Mutation" } & {
  expelServerResponse: $ElementType<Mutation, "expel_server">
};

export type EditReplicasetMutationVariables = {
  uuid: $ElementType<Scalars, "String">,
  roles?: ?Array<$ElementType<Scalars, "String">>,
  vshard_group?: ?$ElementType<Scalars, "String">,
  master: Array<$ElementType<Scalars, "String">>,
  weight?: ?$ElementType<Scalars, "Float">
};

export type EditReplicasetMutation = { __typename?: "Mutation" } & {
  editReplicasetResponse: $ElementType<Mutation, "edit_replicaset">
};

export type JoinSingleServerMutationVariables = {
  uri: $ElementType<Scalars, "String">
};

export type JoinSingleServerMutation = { __typename?: "Mutation" } & {
  joinServerResponse: $ElementType<Mutation, "join_server">
};

export type ChangeFailoverMutationVariables = {
  enabled: $ElementType<Scalars, "Boolean">
};

export type ChangeFailoverMutation = { __typename?: "Mutation" } & {
  cluster: ?({ __typename?: "MutationApicluster" } & $Pick<
    MutationApicluster,
    { failover: * }
  >)
};

export type FetchUsersQueryVariables = {};

export type FetchUsersQuery = { __typename?: "Query" } & {
  cluster: ?({ __typename?: "Apicluster" } & {
    users: ?Array<
      { __typename?: "User" } & $Pick<
        User,
        { username: *, fullname: *, email: * }
      >
    >
  })
};

export type AddUserMutationVariables = {
  username: $ElementType<Scalars, "String">,
  password: $ElementType<Scalars, "String">,
  email: $ElementType<Scalars, "String">,
  fullname: $ElementType<Scalars, "String">
};

export type AddUserMutation = { __typename?: "Mutation" } & {
  cluster: ?({ __typename?: "MutationApicluster" } & {
    add_user: ?({ __typename?: "User" } & $Pick<
      User,
      { username: *, email: *, fullname: * }
    >)
  })
};

export type EditUserMutationVariables = {
  username: $ElementType<Scalars, "String">,
  password?: ?$ElementType<Scalars, "String">,
  email?: ?$ElementType<Scalars, "String">,
  fullname?: ?$ElementType<Scalars, "String">
};

export type EditUserMutation = { __typename?: "Mutation" } & {
  cluster: ?({ __typename?: "MutationApicluster" } & {
    edit_user: ?({ __typename?: "User" } & $Pick<
      User,
      { username: *, email: *, fullname: * }
    >)
  })
};

export type RemoveUserMutationVariables = {
  username: $ElementType<Scalars, "String">
};

export type RemoveUserMutation = { __typename?: "Mutation" } & {
  cluster: ?({ __typename?: "MutationApicluster" } & {
    remove_user: ?({ __typename?: "User" } & $Pick<
      User,
      { username: *, email: *, fullname: * }
    >)
  })
};
