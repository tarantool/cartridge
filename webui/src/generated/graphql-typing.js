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
  auth_params: UserManagementApi,
  /** Whether it is reasonble to call bootstrap_vshard mutation */
  can_bootstrap_vshard: $ElementType<Scalars, 'Boolean'>,
  /** Get cluster config sections */
  config: Array<?ConfigSection>,
  /** Get current failover state. (Deprecated since v2.0.2-2) */
  failover: $ElementType<Scalars, 'Boolean'>,
  /** Get automatic failover configuration. */
  failover_params: FailoverApi,
  /** List issues in cluster */
  issues?: ?Array<Issue>,
  /** Get list of all registered roles and their dependencies. */
  known_roles: Array<Role>,
  /** Clusterwide DDL schema */
  schema: DdlSchema,
  /** Some information about current server */
  self?: ?ServerShortInfo,
  /** Show suggestions to resolve operation problems */
  suggestions?: ?Suggestions,
  /** List authorized users */
  users?: ?Array<User>,
  /** Validate config */
  validate_config: ValidateConfigResult,
  /** Virtual buckets count in cluster */
  vshard_bucket_count: $ElementType<Scalars, 'Int'>,
  vshard_groups: Array<VshardGroup>,
  /** Get list of known vshard storage groups. */
  vshard_known_groups: Array<$ElementType<Scalars, 'String'>>,
  /** List of pages to be hidden in WebUI */
  webui_blacklist?: ?Array<$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type ApiclusterConfigArgs = {|
  sections?: ?Array<$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type ApiclusterUsersArgs = {|
  username?: ?$ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type ApiclusterValidate_ConfigArgs = {|
  sections?: ?Array<?ConfigSectionInput>,
|};

/** A section of clusterwide configuration */
export type ConfigSection = {|
  __typename?: 'ConfigSection',
  content: $ElementType<Scalars, 'String'>,
  filename: $ElementType<Scalars, 'String'>,
|};

/** A section of clusterwide configuration */
export type ConfigSectionInput = {|
  content?: ?$ElementType<Scalars, 'String'>,
  filename: $ElementType<Scalars, 'String'>,
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

/** A suggestion to disable malfunctioning servers in order to restore the quorum */
export type DisableServerSuggestion = {|
  __typename?: 'DisableServerSuggestion',
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Parameters for editing a replicaset */
export type EditReplicasetInput = {|
  alias?: ?$ElementType<Scalars, 'String'>,
  all_rw?: ?$ElementType<Scalars, 'Boolean'>,
  failover_priority?: ?Array<$ElementType<Scalars, 'String'>>,
  join_servers?: ?Array<?JoinServerInput>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  uuid?: ?$ElementType<Scalars, 'String'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  weight?: ?$ElementType<Scalars, 'Float'>,
|};

/** Parameters for editing existing server */
export type EditServerInput = {|
  disabled?: ?$ElementType<Scalars, 'Boolean'>,
  expelled?: ?$ElementType<Scalars, 'Boolean'>,
  labels?: ?Array<?LabelInput>,
  uri?: ?$ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
  zone?: ?$ElementType<Scalars, 'String'>,
|};

export type EditTopologyResult = {|
  __typename?: 'EditTopologyResult',
  replicasets: Array<?Replicaset>,
  servers: Array<?Server>,
|};

export type Error = {|
  __typename?: 'Error',
  class_name?: ?$ElementType<Scalars, 'String'>,
  message: $ElementType<Scalars, 'String'>,
  stack?: ?$ElementType<Scalars, 'String'>,
|};

/** Failover parameters managent */
export type FailoverApi = {|
  __typename?: 'FailoverAPI',
  etcd2_params?: ?FailoverStateProviderCfgEtcd2,
  failover_timeout: $ElementType<Scalars, 'Float'>,
  fencing_enabled: $ElementType<Scalars, 'Boolean'>,
  fencing_pause: $ElementType<Scalars, 'Float'>,
  fencing_timeout: $ElementType<Scalars, 'Float'>,
  /** Supported modes are "disabled", "eventual" and "stateful". */
  mode: $ElementType<Scalars, 'String'>,
  /** Type of external storage for the stateful failover mode. Supported types are "tarantool" and "etcd2". */
  state_provider?: ?$ElementType<Scalars, 'String'>,
  tarantool_params?: ?FailoverStateProviderCfgTarantool,
|};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgEtcd2 = {|
  __typename?: 'FailoverStateProviderCfgEtcd2',
  endpoints: Array<$ElementType<Scalars, 'String'>>,
  lock_delay: $ElementType<Scalars, 'Float'>,
  password: $ElementType<Scalars, 'String'>,
  prefix: $ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
|};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgInputEtcd2 = {|
  endpoints?: ?Array<$ElementType<Scalars, 'String'>>,
  lock_delay?: ?$ElementType<Scalars, 'Float'>,
  password?: ?$ElementType<Scalars, 'String'>,
  prefix?: ?$ElementType<Scalars, 'String'>,
  username?: ?$ElementType<Scalars, 'String'>,
|};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgInputTarantool = {|
  password: $ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
|};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgTarantool = {|
  __typename?: 'FailoverStateProviderCfgTarantool',
  password: $ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
|};

/**
 * A suggestion to reapply configuration forcefully. There may be several reasons
 * to do that: configuration checksum mismatch (config_mismatch); the locking of
 * tho-phase commit (config_locked); an error during previous config update
 * (operation_error).
 */
export type ForceApplySuggestion = {|
  __typename?: 'ForceApplySuggestion',
  config_locked: $ElementType<Scalars, 'Boolean'>,
  config_mismatch: $ElementType<Scalars, 'Boolean'>,
  operation_error: $ElementType<Scalars, 'Boolean'>,
  uuid: $ElementType<Scalars, 'String'>,
|};

export type Issue = {|
  __typename?: 'Issue',
  instance_uuid?: ?$ElementType<Scalars, 'String'>,
  level: $ElementType<Scalars, 'String'>,
  message: $ElementType<Scalars, 'String'>,
  replicaset_uuid?: ?$ElementType<Scalars, 'String'>,
  topic: $ElementType<Scalars, 'String'>,
|};

/** Parameters for joining a new server */
export type JoinServerInput = {|
  labels?: ?Array<?LabelInput>,
  uri: $ElementType<Scalars, 'String'>,
  uuid?: ?$ElementType<Scalars, 'String'>,
  zone?: ?$ElementType<Scalars, 'String'>,
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
  bootstrap_vshard?: ?$ElementType<Scalars, 'Boolean'>,
  /** Cluster management */
  cluster?: ?MutationApicluster,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_replicaset?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_server?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  expel_server?: ?$ElementType<Scalars, 'Boolean'>,
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  join_server?: ?$ElementType<Scalars, 'Boolean'>,
  probe_server?: ?$ElementType<Scalars, 'Boolean'>,
|};


export type MutationEdit_ReplicasetArgs = {|
  alias?: ?$ElementType<Scalars, 'String'>,
  all_rw?: ?$ElementType<Scalars, 'Boolean'>,
  master?: ?Array<$ElementType<Scalars, 'String'>>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  uuid: $ElementType<Scalars, 'String'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  weight?: ?$ElementType<Scalars, 'Float'>,
|};


export type MutationEdit_ServerArgs = {|
  labels?: ?Array<?LabelInput>,
  uri?: ?$ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
|};


export type MutationExpel_ServerArgs = {|
  uuid: $ElementType<Scalars, 'String'>,
|};


export type MutationJoin_ServerArgs = {|
  instance_uuid?: ?$ElementType<Scalars, 'String'>,
  labels?: ?Array<?LabelInput>,
  replicaset_alias?: ?$ElementType<Scalars, 'String'>,
  replicaset_uuid?: ?$ElementType<Scalars, 'String'>,
  replicaset_weight?: ?$ElementType<Scalars, 'Float'>,
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  timeout?: ?$ElementType<Scalars, 'Float'>,
  uri: $ElementType<Scalars, 'String'>,
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  zone?: ?$ElementType<Scalars, 'String'>,
|};


export type MutationProbe_ServerArgs = {|
  uri: $ElementType<Scalars, 'String'>,
|};

/** Cluster management */
export type MutationApicluster = {|
  __typename?: 'MutationApicluster',
  /** Create a new user */
  add_user?: ?User,
  auth_params: UserManagementApi,
  /** Checks that schema can be applied on cluster */
  check_schema: DdlCheckResult,
  /** Applies updated config on cluster */
  config: Array<?ConfigSection>,
  /** Reapplies config on the specified nodes */
  config_force_reapply: $ElementType<Scalars, 'Boolean'>,
  /** Disable listed servers by uuid */
  disable_servers?: ?Array<?Server>,
  /** Edit cluster topology */
  edit_topology?: ?EditTopologyResult,
  /** Edit an existing user */
  edit_user?: ?User,
  edit_vshard_options: VshardGroup,
  /** Enable or disable automatic failover. Returns new state. (Deprecated since v2.0.2-2) */
  failover: $ElementType<Scalars, 'Boolean'>,
  /** Configure automatic failover. */
  failover_params: FailoverApi,
  /** Promote the instance to the leader of replicaset */
  failover_promote: $ElementType<Scalars, 'Boolean'>,
  /** Remove user */
  remove_user?: ?User,
  /** Restart replication on specified by uuid servers */
  restart_replication?: ?$ElementType<Scalars, 'Boolean'>,
  /** Applies DDL schema on cluster */
  schema: DdlSchema,
|};


/** Cluster management */
export type MutationApiclusterAdd_UserArgs = {|
  email?: ?$ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  password: $ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterAuth_ParamsArgs = {|
  cookie_max_age?: ?$ElementType<Scalars, 'Long'>,
  cookie_renew_age?: ?$ElementType<Scalars, 'Long'>,
  enabled?: ?$ElementType<Scalars, 'Boolean'>,
|};


/** Cluster management */
export type MutationApiclusterCheck_SchemaArgs = {|
  as_yaml: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterConfigArgs = {|
  sections?: ?Array<?ConfigSectionInput>,
|};


/** Cluster management */
export type MutationApiclusterConfig_Force_ReapplyArgs = {|
  uuids?: ?Array<?$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type MutationApiclusterDisable_ServersArgs = {|
  uuids?: ?Array<$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type MutationApiclusterEdit_TopologyArgs = {|
  replicasets?: ?Array<?EditReplicasetInput>,
  servers?: ?Array<?EditServerInput>,
|};


/** Cluster management */
export type MutationApiclusterEdit_UserArgs = {|
  email?: ?$ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  password?: ?$ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterEdit_Vshard_OptionsArgs = {|
  collect_bucket_garbage_interval?: ?$ElementType<Scalars, 'Float'>,
  collect_lua_garbage?: ?$ElementType<Scalars, 'Boolean'>,
  name: $ElementType<Scalars, 'String'>,
  rebalancer_disbalance_threshold?: ?$ElementType<Scalars, 'Float'>,
  rebalancer_max_receiving?: ?$ElementType<Scalars, 'Int'>,
  rebalancer_max_sending?: ?$ElementType<Scalars, 'Int'>,
  sched_move_quota?: ?$ElementType<Scalars, 'Long'>,
  sched_ref_quota?: ?$ElementType<Scalars, 'Long'>,
  sync_timeout?: ?$ElementType<Scalars, 'Float'>,
|};


/** Cluster management */
export type MutationApiclusterFailoverArgs = {|
  enabled: $ElementType<Scalars, 'Boolean'>,
|};


/** Cluster management */
export type MutationApiclusterFailover_ParamsArgs = {|
  etcd2_params?: ?FailoverStateProviderCfgInputEtcd2,
  failover_timeout?: ?$ElementType<Scalars, 'Float'>,
  fencing_enabled?: ?$ElementType<Scalars, 'Boolean'>,
  fencing_pause?: ?$ElementType<Scalars, 'Float'>,
  fencing_timeout?: ?$ElementType<Scalars, 'Float'>,
  mode?: ?$ElementType<Scalars, 'String'>,
  state_provider?: ?$ElementType<Scalars, 'String'>,
  tarantool_params?: ?FailoverStateProviderCfgInputTarantool,
|};


/** Cluster management */
export type MutationApiclusterFailover_PromoteArgs = {|
  force_inconsistency?: ?$ElementType<Scalars, 'Boolean'>,
  instance_uuid: $ElementType<Scalars, 'String'>,
  replicaset_uuid: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterRemove_UserArgs = {|
  username: $ElementType<Scalars, 'String'>,
|};


/** Cluster management */
export type MutationApiclusterRestart_ReplicationArgs = {|
  uuids?: ?Array<$ElementType<Scalars, 'String'>>,
|};


/** Cluster management */
export type MutationApiclusterSchemaArgs = {|
  as_yaml: $ElementType<Scalars, 'String'>,
|};

export type Query = {|
  __typename?: 'Query',
  /** Cluster management */
  cluster?: ?Apicluster,
  replicasets?: ?Array<?Replicaset>,
  servers?: ?Array<?Server>,
|};


export type QueryReplicasetsArgs = {|
  uuid?: ?$ElementType<Scalars, 'String'>,
|};


export type QueryServersArgs = {|
  uuid?: ?$ElementType<Scalars, 'String'>,
|};

/** A suggestion to reconfigure cluster topology because  one or more servers were restarted with a new advertise uri */
export type RefineUriSuggestion = {|
  __typename?: 'RefineUriSuggestion',
  uri_new: $ElementType<Scalars, 'String'>,
  uri_old: $ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Statistics for an instance in the replica set. */
export type ReplicaStatus = {|
  __typename?: 'ReplicaStatus',
  downstream_message?: ?$ElementType<Scalars, 'String'>,
  downstream_status?: ?$ElementType<Scalars, 'String'>,
  id?: ?$ElementType<Scalars, 'Int'>,
  lsn?: ?$ElementType<Scalars, 'Long'>,
  upstream_idle?: ?$ElementType<Scalars, 'Float'>,
  upstream_lag?: ?$ElementType<Scalars, 'Float'>,
  upstream_message?: ?$ElementType<Scalars, 'String'>,
  upstream_peer?: ?$ElementType<Scalars, 'String'>,
  upstream_status?: ?$ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
|};

/** Group of servers replicating the same data */
export type Replicaset = {|
  __typename?: 'Replicaset',
  /** The active leader. It may differ from "master" if failover is enabled and configured leader isn't healthy. */
  active_master: Server,
  /** The replica set alias */
  alias: $ElementType<Scalars, 'String'>,
  /** All instances in replica set are rw */
  all_rw: $ElementType<Scalars, 'Boolean'>,
  /** The leader according to the configuration. */
  master: Server,
  /** The role set enabled on every instance in the replica set */
  roles?: ?Array<$ElementType<Scalars, 'String'>>,
  /** Servers in the replica set. */
  servers: Array<Server>,
  /** The replica set health. It is "healthy" if all instances have status "healthy". Otherwise "unhealthy". */
  status: $ElementType<Scalars, 'String'>,
  /** The replica set uuid */
  uuid: $ElementType<Scalars, 'String'>,
  /** Vshard storage group name. Meaningful only when multiple vshard groups are configured. */
  vshard_group?: ?$ElementType<Scalars, 'String'>,
  /** Vshard replica set weight. Null for replica sets with vshard-storage role disabled. */
  weight?: ?$ElementType<Scalars, 'Float'>,
|};

/** A suggestion to restart malfunctioning replications */
export type RestartReplicationSuggestion = {|
  __typename?: 'RestartReplicationSuggestion',
  uuid: $ElementType<Scalars, 'String'>,
|};

export type Role = {|
  __typename?: 'Role',
  dependencies?: ?Array<$ElementType<Scalars, 'String'>>,
  implies_router: $ElementType<Scalars, 'Boolean'>,
  implies_storage: $ElementType<Scalars, 'Boolean'>,
  name: $ElementType<Scalars, 'String'>,
|};

/** A server participating in tarantool cluster */
export type Server = {|
  __typename?: 'Server',
  alias?: ?$ElementType<Scalars, 'String'>,
  boxinfo?: ?ServerInfo,
  /**
   * Difference between remote clock and the current one. Obtained from the
   * membership module (SWIM protocol). Positive values mean remote clock are ahead
   * of local, and vice versa. In seconds.
   */
  clock_delta?: ?$ElementType<Scalars, 'Float'>,
  disabled?: ?$ElementType<Scalars, 'Boolean'>,
  labels?: ?Array<?Label>,
  message: $ElementType<Scalars, 'String'>,
  /** Failover priority within the replica set */
  priority?: ?$ElementType<Scalars, 'Int'>,
  replicaset?: ?Replicaset,
  statistics?: ?ServerStat,
  status: $ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  uuid: $ElementType<Scalars, 'String'>,
  zone?: ?$ElementType<Scalars, 'String'>,
|};

/** Server information and configuration. */
export type ServerInfo = {|
  __typename?: 'ServerInfo',
  cartridge: ServerInfoCartridge,
  general: ServerInfoGeneral,
  membership: ServerInfoMembership,
  network: ServerInfoNetwork,
  replication: ServerInfoReplication,
  storage: ServerInfoStorage,
  /** List of vshard router parameters */
  vshard_router?: ?Array<?VshardRouter>,
  vshard_storage?: ?ServerInfoVshardStorage,
|};

export type ServerInfoCartridge = {|
  __typename?: 'ServerInfoCartridge',
  /** Error details if instance is in failure state */
  error?: ?Error,
  /** Current instance state */
  state: $ElementType<Scalars, 'String'>,
  /** Cartridge version */
  version: $ElementType<Scalars, 'String'>,
|};

export type ServerInfoGeneral = {|
  __typename?: 'ServerInfoGeneral',
  /** A globally unique identifier of the instance */
  instance_uuid: $ElementType<Scalars, 'String'>,
  /** The binary protocol URI */
  listen?: ?$ElementType<Scalars, 'String'>,
  /** A directory where memtx stores snapshot (.snap) files */
  memtx_dir?: ?$ElementType<Scalars, 'String'>,
  /** The process ID */
  pid: $ElementType<Scalars, 'Int'>,
  /** The UUID of the replica set */
  replicaset_uuid: $ElementType<Scalars, 'String'>,
  /** Current read-only state */
  ro: $ElementType<Scalars, 'Boolean'>,
  /** The number of seconds since the instance started */
  uptime: $ElementType<Scalars, 'Float'>,
  /** The Tarantool version */
  version: $ElementType<Scalars, 'String'>,
  /** A directory where vinyl files or subdirectories will be stored */
  vinyl_dir?: ?$ElementType<Scalars, 'String'>,
  /** A directory where write-ahead log (.xlog) files are stored */
  wal_dir?: ?$ElementType<Scalars, 'String'>,
  /** Current working directory of a process */
  work_dir?: ?$ElementType<Scalars, 'String'>,
  /**
   * The maximum number of threads to use during execution of certain internal
   * processes (currently socket.getaddrinfo() and coio_call())
   */
  worker_pool_threads?: ?$ElementType<Scalars, 'Int'>,
|};

export type ServerInfoMembership = {|
  __typename?: 'ServerInfoMembership',
  /** ACK message wait time */
  ACK_TIMEOUT_SECONDS?: ?$ElementType<Scalars, 'Float'>,
  /** Anti-entropy synchronization period */
  ANTI_ENTROPY_PERIOD_SECONDS?: ?$ElementType<Scalars, 'Float'>,
  /** Number of members to ping a suspect indirectly */
  NUM_FAILURE_DETECTION_SUBGROUPS?: ?$ElementType<Scalars, 'Int'>,
  /** Direct ping period */
  PROTOCOL_PERIOD_SECONDS?: ?$ElementType<Scalars, 'Float'>,
  /** Timeout to mark a suspect dead */
  SUSPECT_TIMEOUT_SECONDS?: ?$ElementType<Scalars, 'Float'>,
  /** Value incremented every time the instance became a suspect, dead, or updates its payload */
  incarnation?: ?$ElementType<Scalars, 'Int'>,
  /** Status of the instance */
  status?: ?$ElementType<Scalars, 'String'>,
|};

export type ServerInfoNetwork = {|
  __typename?: 'ServerInfoNetwork',
  io_collect_interval?: ?$ElementType<Scalars, 'Float'>,
  net_msg_max?: ?$ElementType<Scalars, 'Long'>,
  readahead?: ?$ElementType<Scalars, 'Long'>,
|};

export type ServerInfoReplication = {|
  __typename?: 'ServerInfoReplication',
  replication_connect_quorum?: ?$ElementType<Scalars, 'Int'>,
  replication_connect_timeout?: ?$ElementType<Scalars, 'Float'>,
  /** Statistics for all instances in the replica set in regard to the current instance */
  replication_info?: ?Array<?ReplicaStatus>,
  replication_skip_conflict?: ?$ElementType<Scalars, 'Boolean'>,
  replication_sync_lag?: ?$ElementType<Scalars, 'Float'>,
  replication_sync_timeout?: ?$ElementType<Scalars, 'Float'>,
  replication_timeout?: ?$ElementType<Scalars, 'Float'>,
  /** The vector clock of replication log sequence numbers */
  vclock?: ?Array<?$ElementType<Scalars, 'Long'>>,
|};

export type ServerInfoStorage = {|
  __typename?: 'ServerInfoStorage',
  memtx_max_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  memtx_memory?: ?$ElementType<Scalars, 'Long'>,
  memtx_min_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  rows_per_wal?: ?$ElementType<Scalars, 'Long'>,
  too_long_threshold?: ?$ElementType<Scalars, 'Float'>,
  vinyl_bloom_fpr?: ?$ElementType<Scalars, 'Float'>,
  vinyl_cache?: ?$ElementType<Scalars, 'Long'>,
  vinyl_max_tuple_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_memory?: ?$ElementType<Scalars, 'Long'>,
  vinyl_page_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_range_size?: ?$ElementType<Scalars, 'Long'>,
  vinyl_read_threads?: ?$ElementType<Scalars, 'Int'>,
  vinyl_run_count_per_level?: ?$ElementType<Scalars, 'Int'>,
  vinyl_run_size_ratio?: ?$ElementType<Scalars, 'Float'>,
  vinyl_timeout?: ?$ElementType<Scalars, 'Float'>,
  vinyl_write_threads?: ?$ElementType<Scalars, 'Int'>,
  wal_dir_rescan_delay?: ?$ElementType<Scalars, 'Float'>,
  wal_max_size?: ?$ElementType<Scalars, 'Long'>,
  wal_mode?: ?$ElementType<Scalars, 'String'>,
|};

export type ServerInfoVshardStorage = {|
  __typename?: 'ServerInfoVshardStorage',
  /** The number of active buckets on the storage */
  buckets_active?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets that are waiting to be collected by GC */
  buckets_garbage?: ?$ElementType<Scalars, 'Int'>,
  /** The number of pinned buckets on the storage */
  buckets_pinned?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets that are receiving at this time */
  buckets_receiving?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets that are sending at this time */
  buckets_sending?: ?$ElementType<Scalars, 'Int'>,
  /** Total number of buckets on the storage */
  buckets_total?: ?$ElementType<Scalars, 'Int'>,
  /** Vshard group */
  vshard_group?: ?$ElementType<Scalars, 'String'>,
|};

/** A short server information */
export type ServerShortInfo = {|
  __typename?: 'ServerShortInfo',
  alias?: ?$ElementType<Scalars, 'String'>,
  app_name?: ?$ElementType<Scalars, 'String'>,
  demo_uri?: ?$ElementType<Scalars, 'String'>,
  error?: ?$ElementType<Scalars, 'String'>,
  instance_name?: ?$ElementType<Scalars, 'String'>,
  state?: ?$ElementType<Scalars, 'String'>,
  uri: $ElementType<Scalars, 'String'>,
  uuid?: ?$ElementType<Scalars, 'String'>,
|};

/** Slab allocator statistics. This can be used to monitor the total memory usage (in bytes) and memory fragmentation. */
export type ServerStat = {|
  __typename?: 'ServerStat',
  /** The total memory used for tuples and indexes together (including allocated, but currently free slabs) */
  arena_size: $ElementType<Scalars, 'Long'>,
  /** The efficient memory used for storing tuples and indexes together (omitting allocated, but currently free slabs) */
  arena_used: $ElementType<Scalars, 'Long'>,
  /** = arena_used / arena_size */
  arena_used_ratio: $ElementType<Scalars, 'String'>,
  /** The total amount of memory (including allocated, but currently free slabs) used only for tuples, no indexes */
  items_size: $ElementType<Scalars, 'Long'>,
  /** The efficient amount of memory (omitting allocated, but currently free slabs) used only for tuples, no indexes */
  items_used: $ElementType<Scalars, 'Long'>,
  /** = items_used / slab_count * slab_size (these are slabs used only for tuples, no indexes) */
  items_used_ratio: $ElementType<Scalars, 'String'>,
  /**
   * The maximum amount of memory that the slab allocator can use for both tuples
   * and indexes (as configured in the memtx_memory parameter)
   */
  quota_size: $ElementType<Scalars, 'Long'>,
  /** The amount of memory that is already distributed to the slab allocator */
  quota_used: $ElementType<Scalars, 'Long'>,
  /** = quota_used / quota_size */
  quota_used_ratio: $ElementType<Scalars, 'String'>,
  /** Number of buckets active on the storage */
  vshard_buckets_count?: ?$ElementType<Scalars, 'Int'>,
|};

export type Suggestions = {|
  __typename?: 'Suggestions',
  disable_servers?: ?Array<DisableServerSuggestion>,
  force_apply?: ?Array<ForceApplySuggestion>,
  refine_uri?: ?Array<RefineUriSuggestion>,
  restart_replication?: ?Array<RestartReplicationSuggestion>,
|};

/** A single user account information */
export type User = {|
  __typename?: 'User',
  email?: ?$ElementType<Scalars, 'String'>,
  fullname?: ?$ElementType<Scalars, 'String'>,
  username: $ElementType<Scalars, 'String'>,
|};

/** User managent parameters and available operations */
export type UserManagementApi = {|
  __typename?: 'UserManagementAPI',
  /** Number of seconds until the authentication cookie expires. */
  cookie_max_age: $ElementType<Scalars, 'Long'>,
  /** Update provided cookie if it's older then this age. */
  cookie_renew_age: $ElementType<Scalars, 'Long'>,
  /** Whether authentication is enabled. */
  enabled: $ElementType<Scalars, 'Boolean'>,
  implements_add_user: $ElementType<Scalars, 'Boolean'>,
  implements_check_password: $ElementType<Scalars, 'Boolean'>,
  implements_edit_user: $ElementType<Scalars, 'Boolean'>,
  implements_get_user: $ElementType<Scalars, 'Boolean'>,
  implements_list_users: $ElementType<Scalars, 'Boolean'>,
  implements_remove_user: $ElementType<Scalars, 'Boolean'>,
  /** Active session username. */
  username?: ?$ElementType<Scalars, 'String'>,
|};

/** Result of config validation */
export type ValidateConfigResult = {|
  __typename?: 'ValidateConfigResult',
  /** Error details if validation fails, null otherwise */
  error?: ?$ElementType<Scalars, 'String'>,
|};

/** Group of replicasets sharding the same dataset */
export type VshardGroup = {|
  __typename?: 'VshardGroup',
  /** Whether the group is ready to operate */
  bootstrapped: $ElementType<Scalars, 'Boolean'>,
  /** Virtual buckets count in the group */
  bucket_count: $ElementType<Scalars, 'Int'>,
  /** If set to true, the Lua collectgarbage() function is called periodically */
  collect_lua_garbage: $ElementType<Scalars, 'Boolean'>,
  /** Group name */
  name: $ElementType<Scalars, 'String'>,
  /** A maximum bucket disbalance threshold, in percent */
  rebalancer_disbalance_threshold: $ElementType<Scalars, 'Float'>,
  /** The maximum number of buckets that can be received in parallel by a single replica set in the storage group */
  rebalancer_max_receiving: $ElementType<Scalars, 'Int'>,
  /** The maximum number of buckets that can be sent in parallel by a single replica set in the storage group */
  rebalancer_max_sending: $ElementType<Scalars, 'Int'>,
  /** Scheduler bucket move quota */
  sched_move_quota: $ElementType<Scalars, 'Long'>,
  /** Scheduler storage ref quota */
  sched_ref_quota: $ElementType<Scalars, 'Long'>,
  /** Timeout to wait for synchronization of the old master with replicas before demotion */
  sync_timeout: $ElementType<Scalars, 'Float'>,
|};

export type VshardRouter = {|
  __typename?: 'VshardRouter',
  /** The number of buckets known to the router and available for read requests */
  buckets_available_ro?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets known to the router and available for read and write requests */
  buckets_available_rw?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets whose replica sets are not known to the router */
  buckets_unknown?: ?$ElementType<Scalars, 'Int'>,
  /** The number of buckets known to the router but unavailable for any requests */
  buckets_unreachable?: ?$ElementType<Scalars, 'Int'>,
  /** Vshard group */
  vshard_group?: ?$ElementType<Scalars, 'String'>,
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
      ...$Pick<Role, {| name: *, dependencies?: *, implies_storage: *, implies_router: * |}>
    })>, vshard_groups: Array<({
        ...{ __typename?: 'VshardGroup' },
      ...$Pick<VshardGroup, {| name: *, bucket_count: *, bootstrapped: * |}>
    })>, authParams: ({
        ...{ __typename?: 'UserManagementAPI' },
      ...$Pick<UserManagementApi, {| enabled: *, implements_add_user: *, implements_check_password: *, implements_list_users: *, implements_edit_user: *, implements_remove_user: *, username?: * |}>
    }) |}
  }) |}
});

export type ServerDetailsFieldsFragment = ({
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
    }), membership: ({
        ...{ __typename?: 'ServerInfoMembership' },
      ...$Pick<ServerInfoMembership, {| status?: *, incarnation?: *, PROTOCOL_PERIOD_SECONDS?: *, ACK_TIMEOUT_SECONDS?: *, ANTI_ENTROPY_PERIOD_SECONDS?: *, SUSPECT_TIMEOUT_SECONDS?: *, NUM_FAILURE_DETECTION_SUBGROUPS?: * |}>
    }), vshard_router?: ?Array<?({
        ...{ __typename?: 'VshardRouter' },
      ...$Pick<VshardRouter, {| vshard_group?: *, buckets_unreachable?: *, buckets_available_ro?: *, buckets_unknown?: *, buckets_available_rw?: * |}>
    })>, vshard_storage?: ?({
        ...{ __typename?: 'ServerInfoVshardStorage' },
      ...$Pick<ServerInfoVshardStorage, {| vshard_group?: *, buckets_receiving?: *, buckets_active?: *, buckets_total?: *, buckets_garbage?: *, buckets_pinned?: *, buckets_sending?: * |}>
    }), network: ({
        ...{ __typename?: 'ServerInfoNetwork' },
      ...$Pick<ServerInfoNetwork, {| io_collect_interval?: *, net_msg_max?: *, readahead?: * |}>
    }), general: ({
        ...{ __typename?: 'ServerInfoGeneral' },
      ...$Pick<ServerInfoGeneral, {| instance_uuid: *, uptime: *, version: *, ro: * |}>
    }), replication: ({
        ...{ __typename?: 'ServerInfoReplication' },
      ...$Pick<ServerInfoReplication, {| replication_connect_quorum?: *, replication_connect_timeout?: *, replication_sync_timeout?: *, replication_skip_conflict?: *, replication_sync_lag?: *, vclock?: *, replication_timeout?: * |}>,
      ...{| replication_info?: ?Array<?({
          ...{ __typename?: 'ReplicaStatus' },
        ...$Pick<ReplicaStatus, {| downstream_status?: *, id?: *, upstream_peer?: *, upstream_idle?: *, upstream_message?: *, lsn?: *, upstream_lag?: *, upstream_status?: *, uuid: *, downstream_message?: * |}>
      })> |}
    }), storage: ({
        ...{ __typename?: 'ServerInfoStorage' },
      ...$Pick<ServerInfoStorage, {| wal_max_size?: *, vinyl_run_count_per_level?: *, rows_per_wal?: *, vinyl_cache?: *, vinyl_range_size?: *, vinyl_timeout?: *, memtx_min_tuple_size?: *, vinyl_bloom_fpr?: *, vinyl_page_size?: *, memtx_max_tuple_size?: *, vinyl_run_size_ratio?: *, wal_mode?: *, memtx_memory?: *, vinyl_memory?: *, too_long_threshold?: *, vinyl_max_tuple_size?: *, vinyl_write_threads?: *, vinyl_read_threads?: *, wal_dir_rescan_delay?: * |}>
    }) |}
  }) |}
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
      }), membership: ({
          ...{ __typename?: 'ServerInfoMembership' },
        ...$Pick<ServerInfoMembership, {| status?: *, incarnation?: *, PROTOCOL_PERIOD_SECONDS?: *, ACK_TIMEOUT_SECONDS?: *, ANTI_ENTROPY_PERIOD_SECONDS?: *, SUSPECT_TIMEOUT_SECONDS?: *, NUM_FAILURE_DETECTION_SUBGROUPS?: * |}>
      }), vshard_router?: ?Array<?({
          ...{ __typename?: 'VshardRouter' },
        ...$Pick<VshardRouter, {| vshard_group?: *, buckets_unreachable?: *, buckets_available_ro?: *, buckets_unknown?: *, buckets_available_rw?: * |}>
      })>, vshard_storage?: ?({
          ...{ __typename?: 'ServerInfoVshardStorage' },
        ...$Pick<ServerInfoVshardStorage, {| vshard_group?: *, buckets_receiving?: *, buckets_active?: *, buckets_total?: *, buckets_garbage?: *, buckets_pinned?: *, buckets_sending?: * |}>
      }), network: ({
          ...{ __typename?: 'ServerInfoNetwork' },
        ...$Pick<ServerInfoNetwork, {| io_collect_interval?: *, net_msg_max?: *, readahead?: * |}>
      }), general: ({
          ...{ __typename?: 'ServerInfoGeneral' },
        ...$Pick<ServerInfoGeneral, {| instance_uuid: *, uptime: *, version: *, ro: * |}>
      }), replication: ({
          ...{ __typename?: 'ServerInfoReplication' },
        ...$Pick<ServerInfoReplication, {| replication_connect_quorum?: *, replication_connect_timeout?: *, replication_sync_timeout?: *, replication_skip_conflict?: *, replication_sync_lag?: *, vclock?: *, replication_timeout?: * |}>,
        ...{| replication_info?: ?Array<?({
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
  }), descriptionMembership?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionVshardRouter?: ?({
      ...{ __typename?: '__Type' },
    ...{| fields?: ?Array<({
        ...{ __typename?: '__Field' },
      ...$Pick<__Field, {| name: *, description?: * |}>
    })> |}
  }), descriptionVshardStorage?: ?({
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
      }), membership: ({
          ...{ __typename?: 'ServerInfoMembership' },
        ...$Pick<ServerInfoMembership, {| status?: *, incarnation?: *, PROTOCOL_PERIOD_SECONDS?: *, ACK_TIMEOUT_SECONDS?: *, ANTI_ENTROPY_PERIOD_SECONDS?: *, SUSPECT_TIMEOUT_SECONDS?: *, NUM_FAILURE_DETECTION_SUBGROUPS?: * |}>
      }), vshard_router?: ?Array<?({
          ...{ __typename?: 'VshardRouter' },
        ...$Pick<VshardRouter, {| vshard_group?: *, buckets_unreachable?: *, buckets_available_ro?: *, buckets_unknown?: *, buckets_available_rw?: * |}>
      })>, vshard_storage?: ?({
          ...{ __typename?: 'ServerInfoVshardStorage' },
        ...$Pick<ServerInfoVshardStorage, {| vshard_group?: *, buckets_receiving?: *, buckets_active?: *, buckets_total?: *, buckets_garbage?: *, buckets_pinned?: *, buckets_sending?: * |}>
      }), network: ({
          ...{ __typename?: 'ServerInfoNetwork' },
        ...$Pick<ServerInfoNetwork, {| io_collect_interval?: *, net_msg_max?: *, readahead?: * |}>
      }), general: ({
          ...{ __typename?: 'ServerInfoGeneral' },
        ...$Pick<ServerInfoGeneral, {| instance_uuid: *, uptime: *, version: *, ro: * |}>
      }), replication: ({
          ...{ __typename?: 'ServerInfoReplication' },
        ...$Pick<ServerInfoReplication, {| replication_connect_quorum?: *, replication_connect_timeout?: *, replication_sync_timeout?: *, replication_skip_conflict?: *, replication_sync_lag?: *, vclock?: *, replication_timeout?: * |}>,
        ...{| replication_info?: ?Array<?({
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

export type ServerListQueryVariables = {
  withStats: $ElementType<Scalars, 'Boolean'>,
};


export type ServerListQuery = ({
    ...{ __typename?: 'Query' },
  ...{| failover?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| failover_params: ({
        ...{ __typename?: 'FailoverAPI' },
      ...$Pick<FailoverApi, {| mode: * |}>
    }) |}
  }), serverList?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...$Pick<Server, {| uuid: *, alias?: *, disabled?: *, uri: *, zone?: *, status: *, message: * |}>,
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
      ...$Pick<Server, {| uuid: *, alias?: *, disabled?: *, uri: *, priority?: *, status: *, message: * |}>,
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
    })> |}
  })>, serverStat?: ?Array<?({
      ...{ __typename?: 'Server' },
    ...$Pick<Server, {| uuid: *, uri: * |}>,
    ...{| statistics?: ?({
        ...{ __typename?: 'ServerStat' },
      ...$Pick<ServerStat, {| quota_used_ratio: *, arena_used_ratio: *, items_used_ratio: * |}>,
      ...{| quotaSize: $ElementType<ServerStat, 'quota_size'>, arenaUsed: $ElementType<ServerStat, 'arena_used'>, bucketsCount?: $ElementType<ServerStat, 'vshard_buckets_count'> |}
    }) |}
  })>, cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| suggestions?: ?({
        ...{ __typename?: 'Suggestions' },
      ...{| disable_servers?: ?Array<({
          ...{ __typename?: 'DisableServerSuggestion' },
        ...$Pick<DisableServerSuggestion, {| uuid: * |}>
      })>, restart_replication?: ?Array<({
          ...{ __typename?: 'RestartReplicationSuggestion' },
        ...$Pick<RestartReplicationSuggestion, {| uuid: * |}>
      })>, force_apply?: ?Array<({
          ...{ __typename?: 'ForceApplySuggestion' },
        ...$Pick<ForceApplySuggestion, {| config_mismatch: *, config_locked: *, uuid: *, operation_error: * |}>
      })>, refine_uri?: ?Array<({
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
    ...$Pick<Server, {| uuid: *, uri: * |}>,
    ...{| statistics?: ?({
        ...{ __typename?: 'ServerStat' },
      ...$Pick<ServerStat, {| quota_used_ratio: *, arena_used_ratio: *, items_used_ratio: * |}>,
      ...{| quotaSize: $ElementType<ServerStat, 'quota_size'>, arenaUsed: $ElementType<ServerStat, 'arena_used'>, bucketsCount?: $ElementType<ServerStat, 'vshard_buckets_count'> |}
    }) |}
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
  replicasets?: ?Array<EditReplicasetInput> | EditReplicasetInput,
  servers?: ?Array<EditServerInput> | EditServerInput,
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

export type Set_FilesMutationVariables = {
  files?: ?Array<ConfigSectionInput> | ConfigSectionInput,
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

export type Disable_ServersMutationVariables = {
  uuids?: ?Array<$ElementType<Scalars, 'String'>> | $ElementType<Scalars, 'String'>,
};


export type Disable_ServersMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...{| disable_servers?: ?Array<?({
        ...{ __typename?: 'Server' },
      ...$Pick<Server, {| uuid: *, disabled?: * |}>
    })> |}
  }) |}
});

export type Restart_ReplicationMutationVariables = {
  uuids?: ?Array<$ElementType<Scalars, 'String'>> | $ElementType<Scalars, 'String'>,
};


export type Restart_ReplicationMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...$Pick<MutationApicluster, {| restart_replication?: * |}>
  }) |}
});

export type Config_Force_ReapplyMutationVariables = {
  uuids?: ?Array<$ElementType<Scalars, 'String'>> | $ElementType<Scalars, 'String'>,
};


export type Config_Force_ReapplyMutation = ({
    ...{ __typename?: 'Mutation' },
  ...{| cluster?: ?({
      ...{ __typename?: 'MutationApicluster' },
    ...$Pick<MutationApicluster, {| config_force_reapply: * |}>
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

export type GetFailoverParamsQueryVariables = {};


export type GetFailoverParamsQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| failover_params: ({
        ...{ __typename?: 'FailoverAPI' },
      ...$Pick<FailoverApi, {| failover_timeout: *, fencing_enabled: *, fencing_timeout: *, fencing_pause: *, mode: *, state_provider?: * |}>,
      ...{| etcd2_params?: ?({
          ...{ __typename?: 'FailoverStateProviderCfgEtcd2' },
        ...$Pick<FailoverStateProviderCfgEtcd2, {| password: *, lock_delay: *, endpoints: *, username: *, prefix: * |}>
      }), tarantool_params?: ?({
          ...{ __typename?: 'FailoverStateProviderCfgTarantool' },
        ...$Pick<FailoverStateProviderCfgTarantool, {| uri: *, password: * |}>
      }) |}
    }) |}
  }) |}
});

export type ValidateConfigQueryVariables = {
  sections?: ?Array<ConfigSectionInput> | ConfigSectionInput,
};


export type ValidateConfigQuery = ({
    ...{ __typename?: 'Query' },
  ...{| cluster?: ?({
      ...{ __typename?: 'Apicluster' },
    ...{| validate_config: ({
        ...{ __typename?: 'ValidateConfigResult' },
      ...$Pick<ValidateConfigResult, {| error?: * |}>
    }) |}
  }) |}
});
