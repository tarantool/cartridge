// @flow

/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {|
  ID: string,
  String: string,
  Boolean: boolean,
  Int: number,
  Float: number,
  /**
   * The `Long` scalar type represents non-fractional signed whole numeric values.
   * Long can represent values from -(2^52) to 2^52 - 1, inclusive.
   */
  Long: number,
|};

/** Cluster management */
export type Apicluster = {|
  __typename?: 'Apicluster',
  /** Some information about current server */
  self?: ?ServerShortInfo,
  /** Clusterwide DDL schema */
  schema: DdlSchema,
  /** List issues in cluster */
  issues?: ?Array<Issue>,
  /** Get automatic failover configuration. */
  failover_params: FailoverApi,
  /** Get current failover state. (Deprecated since v2.0.2-2) */
  failover: $ElementType<Scalars, 'Boolean'>,
  /** Show suggestions to resolve operation problems */
  suggestions?: ?Suggestions,
  /** List authorized users */
  users?: ?Array<User>,
  /** Whether it is reasonble to call bootstrap_vshard mutation */
  can_bootstrap_vshard: $ElementType<Scalars, 'Boolean'>,
  auth_params: UserManagementApi,
  /** Get list of known vshard storage groups. */
  vshard_known_groups: Array<$ElementType<Scalars, 'String'>>,
  /** List of pages to be hidden in WebUI */
  webui_blacklist?: ?Array<$ElementType<Scalars, 'String'>>,
  vshard_groups: Array<VshardGroup>,
  /** Get list of all registered roles and their dependencies. */
  known_roles: Array<Role>,
  /** Virtual buckets count in cluster */
  vshard_bucket_count: $ElementType<Scalars, 'Int'>,
  /** Get cluster config sections */
  config: Array<?ConfigSection>,
|};


/** Cluster management */
export type ApiclusterUsersArgs = {|
  username?: ?$ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type ApiclusterConfigArgs = {|
  sections?: ?Array<$ElementType<Scalars, 'String'>>,
|};

/** A section of clusterwide configuration */
export type ConfigSection = {|
  __typename?: 'ConfigSection',
  filename: $ElementType<Scalars, 'String'>,
  content: $ElementType<Scalars, 'String'>,
|};

/** A section of clusterwide configuration */
export type ConfigSectionInput = {|
  filename: $ElementType<Scalars, 'String'>,
  content?: ?$ElementType<Scalars, 'String'>,
|};

/** Result of schema validation */
export type DdlCheckResult = {|
  __typename?: 'DDLCheckResult',
  /** Error details if validation fails, null otherwise */
  error?: ?$ElementType<Scalars, 'String'>,
|};

/** The schema */
export type DdlSchema = {|
  __typename?: 'DDLSchema',
  as_yaml: $ElementType<Scalars, 'String'>,
|};

/** A suggestion to disable malfunctioning servers  in order to restore the quorum */
export type DisableServersSuggestion = {|
  __typename?: 'DisableServersSuggestion',
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Parameters for editing a replicaset */
export type EditReplicasetInput = {|
  uuid?: ?$ElementType<Scalars, 'String'>,
  weight?: ?$ElementType<Scalars, 'Float'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  join_servers?: ?Array<?JoinServerInput>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  alias?: ?$ElementType<Scalars, 'String'>,
  all_rw?: ?$ElementType<Scalars, 'Boolean'>,
  failover_priority?: ?Array<$ElementType<Scalars, 'String'>>,
|};

/** Parameters for editing existing server */
export type EditServerInput = {|
  uri?: ?$ElementType<Scalars, 'String'>,
  labels?: ?Array<?LabelInput>,
  disabled?: ?$ElementType<Scalars, 'Boolean'>,
  uuid: $ElementType<Scalars, 'String'>,
  expelled?: ?$ElementType<Scalars, 'Boolean'>,
  zone?: ?$ElementType<Scalars, 'String'>,
|};

export type EditTopologyResult = {|
  __typename?: 'EditTopologyResult',
  replicasets: Array<?Replicaset>,
  servers: Array<?Server>,
|};

export type Error = {|
  __typename?: 'Error',
  stack?: ?$ElementType<Scalars, 'String'>,
  class_name?: ?$ElementType<Scalars, 'String'>,
  message: $ElementType<Scalars, 'String'>,
|};

/** Failover parameters managent */
export type FailoverApi = {|
  __typename?: 'FailoverAPI',
  fencing_enabled: $ElementType<Scalars, 'Boolean'>,
  fencing_timeout: $ElementType<Scalars, 'Float'>,
  failover_timeout: $ElementType<Scalars, 'Float'>,
  /** Supported modes are "disabled", "eventual" and "stateful". */
  mode: $ElementType<Scalars, 'String'>,
  /** Type of external storage for the stateful failover mode. Supported types are "tarantool" and "etcd2". */
  state_provider?: ?$ElementType<Scalars, 'String'>,
  tarantool_params?: ?FailoverStateProviderCfgTarantool,
  fencing_pause: $ElementType<Scalars, 'Float'>,
  etcd2_params?: ?FailoverStateProviderCfgEtcd2,
|};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgEtcd2 = {|
  __typename?: 'FailoverStateProviderCfgEtcd2',
  password: $ElementType<Scalars, 'String'>,
  lock_delay: $ElementType<Scalars, 'Float'>,
  endpoints: Array<$ElementType<Scalars, 'String'>>,
  username: $ElementType<Scalars, 'String'>,
  prefix: $ElementType<Scalars, 'String'>,
|};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgInputEtcd2 = {|
  password?: ?$ElementType<Scalars, 'String'>,
  lock_delay?: ?$ElementType<Scalars, 'Float'>,
  endpoints?: ?Array<$ElementType<Scalars, 'String'>>,
  username?: ?$ElementType<Scalars, 'String'>,
  prefix?: ?$ElementType<Scalars, 'String'>,
|};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgInputTarantool = {|
  uri: $ElementType<Scalars, 'String'>,
  password: $ElementType<Scalars, 'String'>,
|};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgTarantool = {|
  __typename?: 'FailoverStateProviderCfgTarantool',
  uri: $ElementType<Scalars, 'String'>,
  password: $ElementType<Scalars, 'String'>,
|};

/**
 * A suggestion to reapply configuration forcefully. There may be several reasons
 * to do that: configuration checksum mismatch (config_mismatch); the locking of
 * tho-phase commit (config_locked); an error during previous config update
 * (operation_error).
 */
export type ForceApplySuggestion = {|
  __typename?: 'ForceApplySuggestion',
  config_mismatch: $ElementType<Scalars, 'Boolean'>,
  config_locked: $ElementType<Scalars, 'Boolean'>,
  uuid: $ElementType<Scalars, 'String'>,
  operation_error: $ElementType<Scalars, 'Boolean'>,
|};

export type Issue = {|
  __typename?: 'Issue',
  level: $ElementType<Scalars, 'String'>,
  instance_uuid?: ?$ElementType<Scalars, 'String'>,
  replicaset_uuid?: ?$ElementType<Scalars, 'String'>,
  message: $ElementType<Scalars, 'String'>,
  topic: $ElementType<Scalars, 'String'>,
|};

/** Parameters for joining a new server */
export type JoinServerInput = {|
  zone?: ?$ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  uuid?: ?$ElementType<Scalars, 'String'>,
  labels?: ?Array<?LabelInput>,
|};

/** Cluster server label */
export type Label = {|
  __typename?: 'Label',
  name: $ElementType<Scalars, 'String'>,
  value: $ElementType<Scalars, 'String'>,
|};

/** Cluster server label */
export type LabelInput = {|
  name: $ElementType<Scalars, 'String'>,
  value: $ElementType<Scalars, 'String'>,
|};


export type Mutation = {|
  __typename?: 'Mutation',
  /** Cluster management */
  cluster?: ?MutationApicluster,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_server?: ?$ElementType<Scalars, 'Boolean'>,
  probe_server?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_replicaset?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  join_server?: ?$ElementType<Scalars, 'Boolean'>,
  bootstrap_vshard?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  expel_server?: ?$ElementType<Scalars, 'Boolean'>,
|};


export type MutationEdit_ServerArgs = {|
  uuid: $ElementType<Scalars, 'String'>,
  uri?: ?$ElementType<Scalars, 'String'>,
  labels?: ?Array<?LabelInput>,
|};


export type MutationProbe_ServerArgs = {|
  uri: $ElementType<Scalars, 'String'>,
|};


export type MutationEdit_ReplicasetArgs = {|
  weight?: ?$ElementType<Scalars, 'Float'>,
  master?: ?Array<$ElementType<Scalars, 'String'>>,
  alias?: ?$ElementType<Scalars, 'String'>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  uuid: $ElementType<Scalars, 'String'>,
  all_rw?: ?$ElementType<Scalars, 'Boolean'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
|};


export type MutationJoin_ServerArgs = {|
  instance_uuid?: ?$ElementType<Scalars, 'String'>,
  timeout?: ?$ElementType<Scalars, 'Float'>,
  zone?: ?$ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  labels?: ?Array<?LabelInput>,
  replicaset_alias?: ?$ElementType<Scalars, 'String'>,
  replicaset_uuid?: ?$ElementType<Scalars, 'String'>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  replicaset_weight?: ?$ElementType<Scalars, 'Float'>,
|};


export type MutationExpel_ServerArgs = {|
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Cluster management */
export type MutationApicluster = {|
  __typename?: 'MutationApicluster',
  /** Remove user */
  remove_user?: ?User,
  /** Enable or disable automatic failover. Returns new state. (Deprecated since v2.0.2-2) */
  failover: $ElementType<Scalars, 'Boolean'>,
  /** Configure automatic failover. */
  failover_params: FailoverApi,
  /** Applies updated config on cluster */
  config: Array<?ConfigSection>,
  /** Checks that schema can be applied on cluster */
  check_schema: DdlCheckResult,
  /** Create a new user */
  add_user?: ?User,
  /** Reapplies config on the specified nodes */
  config_force_reapply: $ElementType<Scalars, 'Boolean'>,
  auth_params: UserManagementApi,
  /** Edit cluster topology */
  edit_topology?: ?EditTopologyResult,
  /** Edit an existing user */
  edit_user?: ?User,
  edit_vshard_options: VshardGroup,
  /** Promote the instance to the leader of replicaset */
  failover_promote: $ElementType<Scalars, 'Boolean'>,
  /** Applies DDL schema on cluster */
  schema: DdlSchema,
  /** Disable listed servers by uuid */
  disable_servers?: ?Array<?Server>,
|};


/** Cluster management */
export type MutationApiclusterRemove_UserArgs = {|
  username: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterFailoverArgs = {|
  enabled: $ElementType<Scalars, 'Boolean'>,
|};


/** Cluster management */
export type MutationApiclusterFailover_ParamsArgs = {|
  fencing_enabled?: ?$ElementType<Scalars, 'Boolean'>,
  fencing_timeout?: ?$ElementType<Scalars, 'Float'>,
  failover_timeout?: ?$ElementType<Scalars, 'Float'>,
  mode?: ?$ElementType<Scalars, 'String'>,
  state_provider?: ?$ElementType<Scalars, 'String'>,
  tarantool_params?: ?FailoverStateProviderCfgInputTarantool,
  fencing_pause?: ?$ElementType<Scalars, 'Float'>,
  etcd2_params?: ?FailoverStateProviderCfgInputEtcd2,
|};


/** Cluster management */
export type MutationApiclusterConfigArgs = {|
  sections?: ?Array<?ConfigSectionInput>,
|};


/** Cluster management */
export type MutationApiclusterCheck_SchemaArgs = {|
  as_yaml: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterAdd_UserArgs = {|
  password: $ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  email?: ?$ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterConfig_Force_ReapplyArgs = {|
  uuids?: ?Array<?$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type MutationApiclusterAuth_ParamsArgs = {|
  cookie_max_age?: ?$ElementType<Scalars, 'Long'>,
  enabled?: ?$ElementType<Scalars, 'Boolean'>,
  cookie_renew_age?: ?$ElementType<Scalars, 'Long'>,
|};


/** Cluster management */
export type MutationApiclusterEdit_TopologyArgs = {|
  replicasets?: ?Array<?EditReplicasetInput>,
  servers?: ?Array<?EditServerInput>,
|};


/** Cluster management */
export type MutationApiclusterEdit_UserArgs = {|
  password?: ?$ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  email?: ?$ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterEdit_Vshard_OptionsArgs = {|
  rebalancer_max_receiving?: ?$ElementType<Scalars, 'Int'>,
  collect_bucket_garbage_interval?: ?$ElementType<Scalars, 'Float'>,
  collect_lua_garbage?: ?$ElementType<Scalars, 'Boolean'>,
  sync_timeout?: ?$ElementType<Scalars, 'Float'>,
  name: $ElementType<Scalars, 'String'>,
  rebalancer_disbalance_threshold?: ?$ElementType<Scalars, 'Float'>,
|};


/** Cluster management */
export type MutationApiclusterFailover_PromoteArgs = {|
  force_inconsistency?: ?$ElementType<Scalars, 'Boolean'>,
  replicaset_uuid: $ElementType<Scalars, 'String'>,
  instance_uuid: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterSchemaArgs = {|
  as_yaml: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterDisable_ServersArgs = {|
  uuids?: ?Array<$ElementType<Scalars, 'String'>>,
|};

export type Query = {|
  __typename?: 'Query',
  /** Cluster management */
  cluster?: ?Apicluster,
  servers?: ?Array<?Server>,
  replicasets?: ?Array<?Replicaset>,
|};


export type QueryServersArgs = {|
  uuid?: ?$ElementType<Scalars, 'String'>,
|};


export type QueryReplicasetsArgs = {|
  uuid?: ?$ElementType<Scalars, 'String'>,
|};

/** A suggestion to reconfigure cluster topology because  one or more servers were restarted with a new advertise uri */
export type RefineUriSuggestion = {|
  __typename?: 'RefineUriSuggestion',
  uri_new: $ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
  uri_old: $ElementType<Scalars, 'String'>,
|};

/** Group of servers replicating the same data */
export type Replicaset = {|
  __typename?: 'Replicaset',
  /** The active leader. It may differ from "master" if failover is enabled and configured leader isn't healthy. */
  active_master: Server,
  /** The leader according to the configuration. */
  master: Server,
  /** The replica set health. It is "healthy" if all instances have status "healthy". Otherwise "unhealthy". */
  status: $ElementType<Scalars, 'String'>,
  /** All instances in replica set are rw */
  all_rw: $ElementType<Scalars, 'Boolean'>,
  /** Vshard storage group name. Meaningful only when multiple vshard groups are configured. */
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  /** The replica set alias */
  alias: $ElementType<Scalars, 'String'>,
  /** Vshard replica set weight. Null for replica sets with vshard-storage role disabled. */
  weight?: ?$ElementType<Scalars, 'Float'>,
  /** The role set enabled on every instance in the replica set */
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  /** Servers in the replica set. */
  servers: Array<Server>,
  /** The replica set uuid */
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Statistics for an instance in the replica set. */
export type ReplicaStatus = {|
  __typename?: 'ReplicaStatus',
  downstream_status?: ?$ElementType<Scalars, 'String'>,
  id?: ?$ElementType<Scalars, 'Int'>,
  upstream_peer?: ?$ElementType<Scalars, 'String'>,
  upstream_idle?: ?$ElementType<Scalars, 'Float'>,
  upstream_message?: ?$ElementType<Scalars, 'String'>,
  lsn?: ?$ElementType<Scalars, 'Long'>,
  upstream_lag?: ?$ElementType<Scalars, 'Float'>,
  upstream_status?: ?$ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
  downstream_message?: ?$ElementType<Scalars, 'String'>,
|};

export type Role = {|
  __typename?: 'Role',
  dependencies?: ?Array<$ElementType<Scalars, 'String'>>,
  implies_storage: $ElementType<Scalars, 'Boolean'>,
  name: $ElementType<Scalars, 'String'>,
  implies_router: $ElementType<Scalars, 'Boolean'>,
|};

/** A server participating in tarantool cluster */
export type Server = {|
  __typename?: 'Server',
  statistics?: ?ServerStat,
  boxinfo?: ?ServerInfo,
  status: $ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
  zone?: ?$ElementType<Scalars, 'String'>,
  replicaset?: ?Replicaset,
  alias?: ?$ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  labels?: ?Array<?Label>,
  message: $ElementType<Scalars, 'String'>,
  disabled?: ?$ElementType<Scalars, 'Boolean'>,
  /** Failover priority within the replica set */
  priority?: ?$ElementType<Scalars, 'Int'>,
  /**
   * Difference between remote clock and the current one. Obtained from the
   * membership module (SWIM protocol). Positive values mean remote clock are ahead
   * of local, and vice versa. In seconds.
   */
  clock_delta?: ?$ElementType<Scalars, 'Float'>,
|};

/** Server information and configuration. */
export type ServerInfo = {|
  __typename?: 'ServerInfo',
  cartridge: ServerInfoCartridge,
  storage: ServerInfoStorage,
  network: ServerInfoNetwork,
  general: ServerInfoGeneral,
  replication: ServerInfoReplication,
|};

export type ServerInfoCartridge = {|
  __typename?: 'ServerInfoCartridge',
  /** Current instance state */
  state: $ElementType<Scalars, 'String'>,
  /** Cartridge version */
  version: $ElementType<Scalars, 'String'>,
  /** Error details if instance is in failure state */
  error?: ?Error,
|};

export type ServerInfoGeneral = {|
  __typename?: 'ServerInfoGeneral',
  /** A globally unique identifier of the instance */
  instance_uuid: $ElementType<Scalars, 'String'>,
  /** Current read-only state */
  ro: $ElementType<Scalars, 'Boolean'>,
  /** A directory where vinyl files or subdirectories will be stored */
  vinyl_dir?: ?$ElementType<Scalars, 'String'>,
  /**
   * The maximum number of threads to use during execution of certain internal
   * processes (currently socket.getaddrinfo() and coio_call())
   */
  worker_pool_threads?: ?$ElementType<Scalars, 'Int'>,
  /** Current working directory of a process */
  work_dir?: ?$ElementType<Scalars, 'String'>,
  /** The number of seconds since the instance started */
  uptime: $ElementType<Scalars, 'Float'>,
  /** A directory where write-ahead log (.xlog) files are stored */
  wal_dir?: ?$ElementType<Scalars, 'String'>,
  /** The Tarantool version */
  version: $ElementType<Scalars, 'String'>,
  /** The binary protocol URI */
  listen?: ?$ElementType<Scalars, 'String'>,
  /** The process ID */
  pid: $ElementType<Scalars, 'Int'>,
  /** The UUID of the replica set */
  replicaset_uuid: $ElementType<Scalars, 'String'>,
  /** A directory where memtx stores snapshot (.snap) files */
  memtx_dir?: ?$ElementType<Scalars, 'String'>,
|};

export type ServerInfoNetwork = {|
  __typename?: 'ServerInfoNetwork',
  io_collect_interval?: ?$ElementType<Scalars, 'Float'>,
  readahead?: ?$ElementType<Scalars, 'Long'>,
  net_msg_max?: ?$ElementType<Scalars, 'Long'>,
|};

export type ServerInfoReplication = {|
  __typename?: 'ServerInfoReplication',
  replication_connect_quorum?: ?$ElementType<Scalars, 'Int'>,
  replication_connect_timeout?: ?$ElementType<Scalars, 'Float'>,
  replication_sync_timeout?: ?$ElementType<Scalars, 'Float'>,
  replication_skip_conflict?: ?$ElementType<Scalars, 'Boolean'>,
  replication_sync_lag?: ?$ElementType<Scalars, 'Float'>,
  /** Statistics for all instances in the replica set in regard to the current instance */
  replication_info?: ?Array<ReplicaStatus>,
  /** The vector clock of replication log sequence numbers */
  vclock?: ?Array<?$ElementType<Scalars, 'Long'>>,
  replication_timeout?: ?$ElementType<Scalars, 'Float'>,
|};

export type ServerInfoStorage = {|
  __typename?: 'ServerInfoStorage',
  wal_max_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_run_count_per_level?: ?$ElementType<Scalars, 'Int'>,
  rows_per_wal?: ?$ElementType<Scalars, 'Long'>,
  vinyl_cache?: ?$ElementType<Scalars, 'Long'>,
  vinyl_range_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_timeout?: ?$ElementType<Scalars, 'Float'>,
  memtx_min_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_bloom_fpr?: ?$ElementType<Scalars, 'Float'>,
  vinyl_page_size?: ?$ElementType<Scalars, 'Long'>,
  memtx_max_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_run_size_ratio?: ?$ElementType<Scalars, 'Float'>,
  wal_mode?: ?$ElementType<Scalars, 'String'>,
  memtx_memory?: ?$ElementType<Scalars, 'Long'>,
  vinyl_memory?: ?$ElementType<Scalars, 'Long'>,
  too_long_threshold?: ?$ElementType<Scalars, 'Float'>,
  vinyl_max_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_write_threads?: ?$ElementType<Scalars, 'Int'>,
  vinyl_read_threads?: ?$ElementType<Scalars, 'Int'>,
  wal_dir_rescan_delay?: ?$ElementType<Scalars, 'Float'>,
|};

/** A short server information */
export type ServerShortInfo = {|
  __typename?: 'ServerShortInfo',
  error?: ?$ElementType<Scalars, 'String'>,
  demo_uri?: ?$ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  alias?: ?$ElementType<Scalars, 'String'>,
  state?: ?$ElementType<Scalars, 'String'>,
  instance_name?: ?$ElementType<Scalars, 'String'>,
  app_name?: ?$ElementType<Scalars, 'String'>,
  uuid?: ?$ElementType<Scalars, 'String'>,
|};

/** Slab allocator statistics. This can be used to monitor the total memory usage (in bytes) and memory fragmentation. */
export type ServerStat = {|
  __typename?: 'ServerStat',
  /** The total amount of memory (including allocated, but currently free slabs) used only for tuples, no indexes */
  items_size: $ElementType<Scalars, 'Long'>,
  /** Number of buckets active on the storage */
  vshard_buckets_count?: ?$ElementType<Scalars, 'Int'>,
  /**
   * The maximum amount of memory that the slab allocator can use for both tuples
   * and indexes (as configured in the memtx_memory parameter)
   */
  quota_size: $ElementType<Scalars, 'Long'>,
  /** = items_used / slab_count * slab_size (these are slabs used only for tuples, no indexes) */
  items_used_ratio: $ElementType<Scalars, 'String'>,
  /** The amount of memory that is already distributed to the slab allocator */
  quota_used: $ElementType<Scalars, 'Long'>,
  /** = arena_used / arena_size */
  arena_used_ratio: $ElementType<Scalars, 'String'>,
  /** The efficient amount of memory (omitting allocated, but currently free slabs) used only for tuples, no indexes */
  items_used: $ElementType<Scalars, 'Long'>,
  /** = quota_used / quota_size */
  quota_used_ratio: $ElementType<Scalars, 'String'>,
  /** The total memory used for tuples and indexes together (including allocated, but currently free slabs) */
  arena_size: $ElementType<Scalars, 'Long'>,
  /** The efficient memory used for storing tuples and indexes together (omitting allocated, but currently free slabs) */
  arena_used: $ElementType<Scalars, 'Long'>,
|};

export type Suggestions = {|
  __typename?: 'Suggestions',
  force_apply?: ?Array<ForceApplySuggestion>,
  refine_uri?: ?Array<RefineUriSuggestion>,
  disable_servers?: ?Array<DisableServersSuggestion>,
|};

/** A single user account information */
export type User = {|
  __typename?: 'User',
  username: $ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  email?: ?$ElementType<Scalars, 'String'>,
|};

/** User managent parameters and available operations */
export type UserManagementApi = {|
  __typename?: 'UserManagementAPI',
  implements_remove_user: $ElementType<Scalars, 'Boolean'>,
  implements_add_user: $ElementType<Scalars, 'Boolean'>,
  implements_edit_user: $ElementType<Scalars, 'Boolean'>,
  /** Number of seconds until the authentication cookie expires. */
  cookie_max_age: $ElementType<Scalars, 'Long'>,
  /** Update provided cookie if it's older then this age. */
  cookie_renew_age: $ElementType<Scalars, 'Long'>,
  implements_list_users: $ElementType<Scalars, 'Boolean'>,
  /** Whether authentication is enabled. */
  enabled: $ElementType<Scalars, 'Boolean'>,
  /** Active session username. */
  username?: ?$ElementType<Scalars, 'String'>,
  implements_get_user: $ElementType<Scalars, 'Boolean'>,
  implements_check_password: $ElementType<Scalars, 'Boolean'>,
|};

/** Group of replicasets sharding the same dataset */
export type VshardGroup = {|
  __typename?: 'VshardGroup',
  /** The maximum number of buckets that can be received in parallel by a single replica set in the storage group */
  rebalancer_max_receiving: $ElementType<Scalars, 'Int'>,
  /** Virtual buckets count in the group */
  bucket_count: $ElementType<Scalars, 'Int'>,
  /** The interval between garbage collector actions, in seconds */
  collect_bucket_garbage_interval: $ElementType<Scalars, 'Float'>,
  /** Whether the group is ready to operate */
  bootstrapped: $ElementType<Scalars, 'Boolean'>,
  /** If set to true, the Lua collectgarbage() function is called periodically */
  collect_lua_garbage: $ElementType<Scalars, 'Boolean'>,
  /** A maximum bucket disbalance threshold, in percent */
  rebalancer_disbalance_threshold: $ElementType<Scalars, 'Float'>,
  /** Group name */
  name: $ElementType<Scalars, 'String'>,
  /** Timeout to wait for synchronization of the old master with replicas before demotion */
  sync_timeout: $ElementType<Scalars, 'Float'>,
|};

type $Pick<Origin: Object, Keys: Object> = $ObjMapi<Keys, <Key>(k: Key) => $ElementType<Origin, Key>>;

export type ServerStatFieldsFragment = ({
    ...{ __typename?: 'Server' },
  ...$Pick<Server, {| uuid: *, uri: * |}>,
  ...{| statistics?: ?({
      ...{ __typename?: 'ServerStat' },
    ...$Pick<ServerStat, {| quota_used_ratio: *, arena_used_ratio: *, items_used_ratio: * |}>,
    ...{| quotaSize: $ElementType<ServerStat, 'quota_size'>, arenaUsed: $ElementType<ServerStat, 'arena_used'>, bucketsCount?: $ElementType<ServerStat, 'vshard_buckets_count'> |}
  }) |}
});

export type AuthQueryVariables = {};


export type AuthQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| authParams: ({
        ...{ __typename?: 'UserManagementAPI' },
      ...$Pick<UserManagementApi, {| enabled: *, username?: * |}>
    }) |}
  }) |}
});

export type TurnAuthMutationVariables = {
  enabled?: ?$ElementType<Scalars, 'Boolean'>,
};


export type TurnAuthMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| authParams: ({
        ...{ __typename?: 'UserManagementAPI' },
      ...$Pick<UserManagementApi, {| enabled: * |}>
    }) |}
  }) |}
});

export type GetClusterQueryVariables = {};


export type GetClusterQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...$Pick<Apicluster, {| can_bootstrap_vshard: *, vshard_bucket_count: * |}>,
    ...{| MenuBlacklist?: $ElementType<Apicluster, 'webui_blacklist'> |},
    ...{| clusterSelf?: ?({
        ...{ __typename?: 'ServerShortInfo' },
      ...$Pick<ServerShortInfo, {| app_name?: *, instance_name?: *, demo_uri?: * |}>,
      ...{| uri: $ElementType<ServerShortInfo, 'uri'>, uuid?: $ElementType<ServerShortInfo, 'uuid'> |}
    }), failover_params: ({
        ...{ __typename?: 'FailoverAPI' },
      ...$Pick<FailoverApi, {| failover_timeout: *, fencing_enabled: *, fencing_timeout: *, fencing_pause: *, mode: *, state_provider?: * |}>,
      ...{| etcd2_params?: ?({
          ...{ __typename?: 'FailoverStateProviderCfgEtcd2' },
        ...$Pick<FailoverStateProviderCfgEtcd2, {| password: *, lock_delay: *, endpoints: *, username: *, prefix: * |}>
      }), tarantool_params?: ?({
          ...{ __typename?: 'FailoverStateProviderCfgTarantool' },
        ...$Pick<FailoverStateProviderCfgTarantool, {| uri: *, password: * |}>
      }) |}
    }), knownRoles: Array<({
        ...{ __typename?: 'Role' },
      ...$Pick<Role, {| name: *, dependencies?: * |}>
    })>, vshard_groups: Array<({
        ...{ __typename?: 'VshardGroup' },
      ...$Pick<VshardGroup, {| name: *, bucket_count: *, bootstrapped: * |}>
    })>, authParams: ({
        ...{ __typename?: 'UserManagementAPI' },
      ...$Pick<UserManagementApi, {| enabled: *, implements_add_user: *, implements_check_password: *, implements_list_users: *, implements_edit_user: *, implements_remove_user: *, username?: * |}>
    }) |}
  }) |}
});

export type BoxInfoQueryVariables = {
  uuid?: ?$ElementType<Scalars, 'String'>,
};


export type BoxInfoQuery = ({
    ...{ __typename?: 'Query' },
  ...{| servers?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...$Pick<Server, {| alias?: *, status: *, message: *, uri: * |}>,
    ...{| replicaset?: ?({
        ...{ __typename?: 'Replicaset' },
      ...$Pick<Replicaset, {| roles?: * |}>,
      ...{| active_master: ({
          ...{ __typename?: 'Server' },
        ...$Pick<Server, {| uuid: * |}>
      }), master: ({
          ...{ __typename?: 'Server' },
        ...$Pick<Server, {| uuid: * |}>
      }) |}
    }), labels?: ?Array<?({
        ...{ __typename?: 'Label' },
      ...$Pick<Label, {| name: *, value: * |}>
    })>, boxinfo?: ?({
        ...{ __typename?: 'ServerInfo' },
      ...{| cartridge: ({
          ...{ __typename?: 'ServerInfoCartridge' },
        ...$Pick<ServerInfoCartridge, {| version: * |}>
      }), network: ({
          ...{ __typename?: 'ServerInfoNetwork' },
        ...$Pick<ServerInfoNetwork, {| io_collect_interval?: *, net_msg_max?: *, readahead?: * |}>
      }), general: ({
          ...{ __typename?: 'ServerInfoGeneral' },
        ...$Pick<ServerInfoGeneral, {| instance_uuid: *, uptime: *, version: *, ro: * |}>
      }), replication: ({
          ...{ __typename?: 'ServerInfoReplication' },
        ...$Pick<ServerInfoReplication, {| replication_connect_quorum?: *, replication_connect_timeout?: *, replication_sync_timeout?: *, replication_skip_conflict?: *, replication_sync_lag?: *, vclock?: *, replication_timeout?: * |}>,
        ...{| replication_info?: ?Array<({
            ...{ __typename?: 'ReplicaStatus' },
          ...$Pick<ReplicaStatus, {| downstream_status?: *, id?: *, upstream_peer?: *, upstream_idle?: *, upstream_message?: *, lsn?: *, upstream_lag?: *, upstream_status?: *, uuid: *, downstream_message?: * |}>
        })> |}
      }), storage: ({
          ...{ __typename?: 'ServerInfoStorage' },
        ...$Pick<ServerInfoStorage, {| wal_max_size?: *, vinyl_run_count_per_level?: *, rows_per_wal?: *, vinyl_cache?: *, vinyl_range_size?: *, vinyl_timeout?: *, memtx_min_tuple_size?: *, vinyl_bloom_fpr?: *, vinyl_page_size?: *, memtx_max_tuple_size?: *, vinyl_run_size_ratio?: *, wal_mode?: *, memtx_memory?: *, vinyl_memory?: *, too_long_threshold?: *, vinyl_max_tuple_size?: *, vinyl_write_threads?: *, vinyl_read_threads?: *, wal_dir_rescan_delay?: * |}>
      }) |}
    }) |}
  })> |}
});

export type InstanceDataQueryVariables = {
  uuid?: ?$ElementType<Scalars, 'String'>,
};


export type InstanceDataQuery = ({
    ...{ __typename?: 'Query' },
  ...{| servers?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...$Pick<Server, {| alias?: *, status: *, message: *, uri: * |}>,
    ...{| replicaset?: ?({
        ...{ __typename?: 'Replicaset' },
      ...$Pick<Replicaset, {| roles?: * |}>,
      ...{| active_master: ({
          ...{ __typename?: 'Server' },
        ...$Pick<Server, {| uuid: * |}>
      }), master: ({
          ...{ __typename?: 'Server' },
        ...$Pick<Server, {| uuid: * |}>
      }) |}
    }), labels?: ?Array<?({
        ...{ __typename?: 'Label' },
      ...$Pick<Label, {| name: *, value: * |}>
    })>, boxinfo?: ?({
        ...{ __typename?: 'ServerInfo' },
      ...{| cartridge: ({
          ...{ __typename?: 'ServerInfoCartridge' },
        ...$Pick<ServerInfoCartridge, {| version: * |}>
      }), network: ({
          ...{ __typename?: 'ServerInfoNetwork' },
        ...$Pick<ServerInfoNetwork, {| io_collect_interval?: *, net_msg_max?: *, readahead?: * |}>
      }), general: ({
          ...{ __typename?: 'ServerInfoGeneral' },
        ...$Pick<ServerInfoGeneral, {| instance_uuid: *, uptime: *, version: *, ro: * |}>
      }), replication: ({
          ...{ __typename?: 'ServerInfoReplication' },
        ...$Pick<ServerInfoReplication, {| replication_connect_quorum?: *, replication_connect_timeout?: *, replication_sync_timeout?: *, replication_skip_conflict?: *, replication_sync_lag?: *, vclock?: *, replication_timeout?: * |}>,
        ...{| replication_info?: ?Array<({
            ...{ __typename?: 'ReplicaStatus' },
          ...$Pick<ReplicaStatus, {| downstream_status?: *, id?: *, upstream_peer?: *, upstream_idle?: *, upstream_message?: *, lsn?: *, upstream_lag?: *, upstream_status?: *, uuid: *, downstream_message?: * |}>
        })> |}
      }), storage: ({
          ...{ __typename?: 'ServerInfoStorage' },
        ...$Pick<ServerInfoStorage, {| wal_max_size?: *, vinyl_run_count_per_level?: *, rows_per_wal?: *, vinyl_cache?: *, vinyl_range_size?: *, vinyl_timeout?: *, memtx_min_tuple_size?: *, vinyl_bloom_fpr?: *, vinyl_page_size?: *, memtx_max_tuple_size?: *, vinyl_run_size_ratio?: *, wal_mode?: *, memtx_memory?: *, vinyl_memory?: *, too_long_threshold?: *, vinyl_max_tuple_size?: *, vinyl_write_threads?: *, vinyl_read_threads?: *, wal_dir_rescan_delay?: * |}>
      }) |}
    }) |}
  })>, descriptionCartridge?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionGeneral?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionNetwork?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionReplication?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionStorage?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }) |}
});

export type ServerListQueryVariables = {
  withStats: $ElementType<Scalars, 'Boolean'>,
};


export type ServerListQuery = ({
    ...{ __typename?: 'Query' },
  ...{| serverList?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...$Pick<Server, {| uuid: *, alias?: *, uri: *, zone?: *, status: *, message: * |}>,
    ...{| boxinfo?: ?({
        ...{ __typename?: 'ServerInfo' },
      ...{| general: ({
          ...{ __typename?: 'ServerInfoGeneral' },
        ...$Pick<ServerInfoGeneral, {| ro: * |}>
      }) |}
    }), replicaset?: ?({
        ...{ __typename?: 'Replicaset' },
      ...$Pick<Replicaset, {| uuid: * |}>
    }) |}
  })>, replicasetList?: ?Array<?({
      ...{ __typename?: 'Replicaset' },
    ...$Pick<Replicaset, {| alias: *, all_rw: *, uuid: *, status: *, roles?: *, vshard_group?: *, weight?: * |}>,
    ...{| master: ({
        ...{ __typename?: 'Server' },
      ...$Pick<Server, {| uuid: * |}>
    }), active_master: ({
        ...{ __typename?: 'Server' },
      ...$Pick<Server, {| uuid: * |}>
    }), servers: Array<({
        ...{ __typename?: 'Server' },
      ...$Pick<Server, {| uuid: *, alias?: *, uri: *, priority?: *, status: *, message: * |}>,
      ...{| boxinfo?: ?({
          ...{ __typename?: 'ServerInfo' },
        ...{| general: ({
            ...{ __typename?: 'ServerInfoGeneral' },
          ...$Pick<ServerInfoGeneral, {| ro: * |}>
        }) |}
      }), replicaset?: ?({
          ...{ __typename?: 'Replicaset' },
        ...$Pick<Replicaset, {| uuid: * |}>
      }), labels?: ?Array<?({
          ...{ __typename?: 'Label' },
        ...$Pick<Label, {| name: *, value: * |}>
      })> |}
    })> |}
  })>, serverStat?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...ServerStatFieldsFragment
  })>, cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| suggestions?: ?({
        ...{ __typename?: 'Suggestions' },
      ...{| refine_uri?: ?Array<({
          ...{ __typename?: 'RefineUriSuggestion' },
        ...$Pick<RefineUriSuggestion, {| uuid: *, uri_old: *, uri_new: * |}>
      })> |}
    }), issues?: ?Array<({
        ...{ __typename?: 'Issue' },
      ...$Pick<Issue, {| level: *, replicaset_uuid?: *, instance_uuid?: *, message: *, topic: * |}>
    })> |}
  }) |}
});

export type ServerStatQueryVariables = {};


export type ServerStatQuery = ({
    ...{ __typename?: 'Query' },
  ...{| serverStat?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...ServerStatFieldsFragment
  })> |}
});

export type BootstrapMutationVariables = {};


export type BootstrapMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| bootstrapVshardResponse?: $ElementType<Mutation, 'bootstrap_vshard'> |}
});

export type ProbeMutationVariables = {
  uri: $ElementType<Scalars, 'String'>,
};


export type ProbeMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| probeServerResponse?: $ElementType<Mutation, 'probe_server'> |}
});

export type EditTopologyMutationVariables = {
  replicasets?: ?Array<EditReplicasetInput>,
  servers?: ?Array<EditServerInput>,
};


export type EditTopologyMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| edit_topology?: ?({
        ...{ __typename?: 'EditTopologyResult' },
      ...{| servers: Array<?({
          ...{ __typename?: 'Server' },
        ...$Pick<Server, {| uuid: * |}>
      })> |}
    }) |}
  }) |}
});

export type ChangeFailoverMutationVariables = {
  failover_timeout?: ?$ElementType<Scalars, 'Float'>,
  fencing_enabled?: ?$ElementType<Scalars, 'Boolean'>,
  fencing_timeout?: ?$ElementType<Scalars, 'Float'>,
  fencing_pause?: ?$ElementType<Scalars, 'Float'>,
  mode: $ElementType<Scalars, 'String'>,
  state_provider?: ?$ElementType<Scalars, 'String'>,
  etcd2_params?: ?FailoverStateProviderCfgInputEtcd2,
  tarantool_params?: ?FailoverStateProviderCfgInputTarantool,
};


export type ChangeFailoverMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| failover_params: ({
        ...{ __typename?: 'FailoverAPI' },
      ...$Pick<FailoverApi, {| mode: * |}>
    }) |}
  }) |}
});

export type PromoteFailoverLeaderMutationVariables = {
  replicaset_uuid: $ElementType<Scalars, 'String'>,
  instance_uuid: $ElementType<Scalars, 'String'>,
  force_inconsistency?: ?$ElementType<Scalars, 'Boolean'>,
};


export type PromoteFailoverLeaderMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...$Pick<MutationApicluster, {| failover_promote: * |}>
  }) |}
});

export type FetchUsersQueryVariables = {};


export type FetchUsersQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| users?: ?Array<({
        ...{ __typename?: 'User' },
      ...$Pick<User, {| username: *, fullname?: *, email?: * |}>
    })> |}
  }) |}
});

export type AddUserMutationVariables = {
  username: $ElementType<Scalars, 'String'>,
  password: $ElementType<Scalars, 'String'>,
  email: $ElementType<Scalars, 'String'>,
  fullname: $ElementType<Scalars, 'String'>,
};


export type AddUserMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| add_user?: ?({
        ...{ __typename?: 'User' },
      ...$Pick<User, {| username: *, email?: *, fullname?: * |}>
    }) |}
  }) |}
});

export type EditUserMutationVariables = {
  username: $ElementType<Scalars, 'String'>,
  password?: ?$ElementType<Scalars, 'String'>,
  email?: ?$ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
};


export type EditUserMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| edit_user?: ?({
        ...{ __typename?: 'User' },
      ...$Pick<User, {| username: *, email?: *, fullname?: * |}>
    }) |}
  }) |}
});

export type RemoveUserMutationVariables = {
  username: $ElementType<Scalars, 'String'>,
};


export type RemoveUserMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| remove_user?: ?({
        ...{ __typename?: 'User' },
      ...$Pick<User, {| username: *, email?: *, fullname?: * |}>
    }) |}
  }) |}
});

export type Get_SchemaQueryVariables = {};


export type Get_SchemaQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| schema: ({
        ...{ __typename?: 'DDLSchema' },
      ...$Pick<DdlSchema, {| as_yaml: * |}>
    }) |}
  }) |}
});

export type Set_SchemaMutationVariables = {
  yaml: $ElementType<Scalars, 'String'>,
};


export type Set_SchemaMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| schema: ({
        ...{ __typename?: 'DDLSchema' },
      ...$Pick<DdlSchema, {| as_yaml: * |}>
    }) |}
  }) |}
});

export type Check_SchemaMutationVariables = {
  yaml: $ElementType<Scalars, 'String'>,
};


export type Check_SchemaMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| check_schema: ({
        ...{ __typename?: 'DDLCheckResult' },
      ...$Pick<DdlCheckResult, {| error?: * |}>
    }) |}
  }) |}
});

export type Set_FilesMutationVariables = {
  files?: ?Array<ConfigSectionInput>,
};


export type Set_FilesMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| config: Array<?({
        ...{ __typename?: 'ConfigSection' },
      ...$Pick<ConfigSection, {| filename: *, content: * |}>
    })> |}
  }) |}
});

export type ConfigFilesQueryVariables = {};


export type ConfigFilesQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| config: Array<?({
        ...{ __typename?: 'ConfigSection' },
      ...$Pick<ConfigSection, {| content: * |}>,
      ...{| path: $ElementType<ConfigSection, 'filename'> |}
    })> |}
  }) |}
});
