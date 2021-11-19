export type Maybe<T> = T | null;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: string;
  String: string;
  Boolean: boolean;
  Int: number;
  Float: number;
  /**
   * The `Long` scalar type represents non-fractional signed whole numeric values.
   * Long can represent values from -(2^52) to 2^52 - 1, inclusive.
   */
  Long: number;
};

/** Cluster management */
export type Apicluster = {
  __typename?: 'Apicluster';
  auth_params: UserManagementApi;
  /** Whether it is reasonble to call bootstrap_vshard mutation */
  can_bootstrap_vshard: Scalars['Boolean'];
  /** Get cluster config sections */
  config: Array<Maybe<ConfigSection>>;
  /** Get current failover state. (Deprecated since v2.0.2-2) */
  failover: Scalars['Boolean'];
  /** Get automatic failover configuration. */
  failover_params: FailoverApi;
  /** List issues in cluster */
  issues?: Maybe<Array<Issue>>;
  /** Get list of all registered roles and their dependencies. */
  known_roles: Array<Role>;
  /** Clusterwide DDL schema */
  schema: DdlSchema;
  /** Some information about current server */
  self?: Maybe<ServerShortInfo>;
  /** Show suggestions to resolve operation problems */
  suggestions?: Maybe<Suggestions>;
  /** List authorized users */
  users?: Maybe<Array<User>>;
  /** Validate config */
  validate_config: ValidateConfigResult;
  /** Virtual buckets count in cluster */
  vshard_bucket_count: Scalars['Int'];
  vshard_groups: Array<VshardGroup>;
  /** Get list of known vshard storage groups. */
  vshard_known_groups: Array<Scalars['String']>;
  /** List of pages to be hidden in WebUI */
  webui_blacklist?: Maybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type ApiclusterConfigArgs = {
  sections?: Maybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type ApiclusterUsersArgs = {
  username?: Maybe<Scalars['String']>;
};

/** Cluster management */
export type ApiclusterValidate_ConfigArgs = {
  sections?: Maybe<Array<Maybe<ConfigSectionInput>>>;
};

/** A section of clusterwide configuration */
export type ConfigSection = {
  __typename?: 'ConfigSection';
  content: Scalars['String'];
  filename: Scalars['String'];
};

/** A section of clusterwide configuration */
export type ConfigSectionInput = {
  content?: Maybe<Scalars['String']>;
  filename: Scalars['String'];
};

/** Result of schema validation */
export type DdlCheckResult = {
  __typename?: 'DDLCheckResult';
  /** Error details if validation fails, null otherwise */
  error?: Maybe<Scalars['String']>;
};

/** The schema */
export type DdlSchema = {
  __typename?: 'DDLSchema';
  as_yaml: Scalars['String'];
};

/** A suggestion to disable malfunctioning servers in order to restore the quorum */
export type DisableServerSuggestion = {
  __typename?: 'DisableServerSuggestion';
  uuid: Scalars['String'];
};

/** Parameters for editing a replicaset */
export type EditReplicasetInput = {
  alias?: Maybe<Scalars['String']>;
  all_rw?: Maybe<Scalars['Boolean']>;
  failover_priority?: Maybe<Array<Scalars['String']>>;
  join_servers?: Maybe<Array<Maybe<JoinServerInput>>>;
  roles?: Maybe<Array<Scalars['String']>>;
  uuid?: Maybe<Scalars['String']>;
  vshard_group?: Maybe<Scalars['String']>;
  weight?: Maybe<Scalars['Float']>;
};

/** Parameters for editing existing server */
export type EditServerInput = {
  disabled?: Maybe<Scalars['Boolean']>;
  expelled?: Maybe<Scalars['Boolean']>;
  labels?: Maybe<Array<Maybe<LabelInput>>>;
  uri?: Maybe<Scalars['String']>;
  uuid: Scalars['String'];
  zone?: Maybe<Scalars['String']>;
};

export type EditTopologyResult = {
  __typename?: 'EditTopologyResult';
  replicasets: Array<Maybe<Replicaset>>;
  servers: Array<Maybe<Server>>;
};

export type Error = {
  __typename?: 'Error';
  class_name?: Maybe<Scalars['String']>;
  message: Scalars['String'];
  stack?: Maybe<Scalars['String']>;
};

/** Failover parameters managent */
export type FailoverApi = {
  __typename?: 'FailoverAPI';
  etcd2_params?: Maybe<FailoverStateProviderCfgEtcd2>;
  failover_timeout: Scalars['Float'];
  fencing_enabled: Scalars['Boolean'];
  fencing_pause: Scalars['Float'];
  fencing_timeout: Scalars['Float'];
  /** Supported modes are "disabled", "eventual" and "stateful". */
  mode: Scalars['String'];
  /** Type of external storage for the stateful failover mode. Supported types are "tarantool" and "etcd2". */
  state_provider?: Maybe<Scalars['String']>;
  tarantool_params?: Maybe<FailoverStateProviderCfgTarantool>;
};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgEtcd2 = {
  __typename?: 'FailoverStateProviderCfgEtcd2';
  endpoints: Array<Scalars['String']>;
  lock_delay: Scalars['Float'];
  password: Scalars['String'];
  prefix: Scalars['String'];
  username: Scalars['String'];
};

/** State provider configuration (etcd-v2) */
export type FailoverStateProviderCfgInputEtcd2 = {
  endpoints?: Maybe<Array<Scalars['String']>>;
  lock_delay?: Maybe<Scalars['Float']>;
  password?: Maybe<Scalars['String']>;
  prefix?: Maybe<Scalars['String']>;
  username?: Maybe<Scalars['String']>;
};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgInputTarantool = {
  password: Scalars['String'];
  uri: Scalars['String'];
};

/** State provider configuration (Tarantool) */
export type FailoverStateProviderCfgTarantool = {
  __typename?: 'FailoverStateProviderCfgTarantool';
  password: Scalars['String'];
  uri: Scalars['String'];
};

/**
 * A suggestion to reapply configuration forcefully. There may be several reasons
 * to do that: configuration checksum mismatch (config_mismatch); the locking of
 * tho-phase commit (config_locked); an error during previous config update
 * (operation_error).
 */
export type ForceApplySuggestion = {
  __typename?: 'ForceApplySuggestion';
  config_locked: Scalars['Boolean'];
  config_mismatch: Scalars['Boolean'];
  operation_error: Scalars['Boolean'];
  uuid: Scalars['String'];
};

export type Issue = {
  __typename?: 'Issue';
  instance_uuid?: Maybe<Scalars['String']>;
  level: Scalars['String'];
  message: Scalars['String'];
  replicaset_uuid?: Maybe<Scalars['String']>;
  topic: Scalars['String'];
};

/** Parameters for joining a new server */
export type JoinServerInput = {
  labels?: Maybe<Array<Maybe<LabelInput>>>;
  uri: Scalars['String'];
  uuid?: Maybe<Scalars['String']>;
  zone?: Maybe<Scalars['String']>;
};

/** Cluster server label */
export type Label = {
  __typename?: 'Label';
  name: Scalars['String'];
  value: Scalars['String'];
};

/** Cluster server label */
export type LabelInput = {
  name: Scalars['String'];
  value: Scalars['String'];
};

export type Mutation = {
  __typename?: 'Mutation';
  bootstrap_vshard?: Maybe<Scalars['Boolean']>;
  /** Cluster management */
  cluster?: Maybe<MutationApicluster>;
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_replicaset?: Maybe<Scalars['Boolean']>;
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  edit_server?: Maybe<Scalars['Boolean']>;
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  expel_server?: Maybe<Scalars['Boolean']>;
  /** Deprecated. Use `cluster{edit_topology()}` instead. */
  join_server?: Maybe<Scalars['Boolean']>;
  probe_server?: Maybe<Scalars['Boolean']>;
};

export type MutationEdit_ReplicasetArgs = {
  alias?: Maybe<Scalars['String']>;
  all_rw?: Maybe<Scalars['Boolean']>;
  master?: Maybe<Array<Scalars['String']>>;
  roles?: Maybe<Array<Scalars['String']>>;
  uuid: Scalars['String'];
  vshard_group?: Maybe<Scalars['String']>;
  weight?: Maybe<Scalars['Float']>;
};

export type MutationEdit_ServerArgs = {
  labels?: Maybe<Array<Maybe<LabelInput>>>;
  uri?: Maybe<Scalars['String']>;
  uuid: Scalars['String'];
};

export type MutationExpel_ServerArgs = {
  uuid: Scalars['String'];
};

export type MutationJoin_ServerArgs = {
  instance_uuid?: Maybe<Scalars['String']>;
  labels?: Maybe<Array<Maybe<LabelInput>>>;
  replicaset_alias?: Maybe<Scalars['String']>;
  replicaset_uuid?: Maybe<Scalars['String']>;
  replicaset_weight?: Maybe<Scalars['Float']>;
  roles?: Maybe<Array<Scalars['String']>>;
  timeout?: Maybe<Scalars['Float']>;
  uri: Scalars['String'];
  vshard_group?: Maybe<Scalars['String']>;
  zone?: Maybe<Scalars['String']>;
};

export type MutationProbe_ServerArgs = {
  uri: Scalars['String'];
};

/** Cluster management */
export type MutationApicluster = {
  __typename?: 'MutationApicluster';
  /** Create a new user */
  add_user?: Maybe<User>;
  auth_params: UserManagementApi;
  /** Checks that schema can be applied on cluster */
  check_schema: DdlCheckResult;
  /** Applies updated config on cluster */
  config: Array<Maybe<ConfigSection>>;
  /** Reapplies config on the specified nodes */
  config_force_reapply: Scalars['Boolean'];
  /** Disable listed servers by uuid */
  disable_servers?: Maybe<Array<Maybe<Server>>>;
  /** Edit cluster topology */
  edit_topology?: Maybe<EditTopologyResult>;
  /** Edit an existing user */
  edit_user?: Maybe<User>;
  edit_vshard_options: VshardGroup;
  /** Enable or disable automatic failover. Returns new state. (Deprecated since v2.0.2-2) */
  failover: Scalars['Boolean'];
  /** Configure automatic failover. */
  failover_params: FailoverApi;
  /** Promote the instance to the leader of replicaset */
  failover_promote: Scalars['Boolean'];
  /** Remove user */
  remove_user?: Maybe<User>;
  /** Restart replication on specified by uuid servers */
  restart_replication?: Maybe<Scalars['Boolean']>;
  /** Applies DDL schema on cluster */
  schema: DdlSchema;
};

/** Cluster management */
export type MutationApiclusterAdd_UserArgs = {
  email?: Maybe<Scalars['String']>;
  fullname?: Maybe<Scalars['String']>;
  password: Scalars['String'];
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterAuth_ParamsArgs = {
  cookie_max_age?: Maybe<Scalars['Long']>;
  cookie_renew_age?: Maybe<Scalars['Long']>;
  enabled?: Maybe<Scalars['Boolean']>;
};

/** Cluster management */
export type MutationApiclusterCheck_SchemaArgs = {
  as_yaml: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterConfigArgs = {
  sections?: Maybe<Array<Maybe<ConfigSectionInput>>>;
};

/** Cluster management */
export type MutationApiclusterConfig_Force_ReapplyArgs = {
  uuids?: Maybe<Array<Maybe<Scalars['String']>>>;
};

/** Cluster management */
export type MutationApiclusterDisable_ServersArgs = {
  uuids?: Maybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type MutationApiclusterEdit_TopologyArgs = {
  replicasets?: Maybe<Array<Maybe<EditReplicasetInput>>>;
  servers?: Maybe<Array<Maybe<EditServerInput>>>;
};

/** Cluster management */
export type MutationApiclusterEdit_UserArgs = {
  email?: Maybe<Scalars['String']>;
  fullname?: Maybe<Scalars['String']>;
  password?: Maybe<Scalars['String']>;
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterEdit_Vshard_OptionsArgs = {
  collect_bucket_garbage_interval?: Maybe<Scalars['Float']>;
  collect_lua_garbage?: Maybe<Scalars['Boolean']>;
  name: Scalars['String'];
  rebalancer_disbalance_threshold?: Maybe<Scalars['Float']>;
  rebalancer_max_receiving?: Maybe<Scalars['Int']>;
  rebalancer_max_sending?: Maybe<Scalars['Int']>;
  sched_move_quota?: Maybe<Scalars['Long']>;
  sched_ref_quota?: Maybe<Scalars['Long']>;
  sync_timeout?: Maybe<Scalars['Float']>;
};

/** Cluster management */
export type MutationApiclusterFailoverArgs = {
  enabled: Scalars['Boolean'];
};

/** Cluster management */
export type MutationApiclusterFailover_ParamsArgs = {
  etcd2_params?: Maybe<FailoverStateProviderCfgInputEtcd2>;
  failover_timeout?: Maybe<Scalars['Float']>;
  fencing_enabled?: Maybe<Scalars['Boolean']>;
  fencing_pause?: Maybe<Scalars['Float']>;
  fencing_timeout?: Maybe<Scalars['Float']>;
  mode?: Maybe<Scalars['String']>;
  state_provider?: Maybe<Scalars['String']>;
  tarantool_params?: Maybe<FailoverStateProviderCfgInputTarantool>;
};

/** Cluster management */
export type MutationApiclusterFailover_PromoteArgs = {
  force_inconsistency?: Maybe<Scalars['Boolean']>;
  instance_uuid: Scalars['String'];
  replicaset_uuid: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterRemove_UserArgs = {
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterRestart_ReplicationArgs = {
  uuids?: Maybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type MutationApiclusterSchemaArgs = {
  as_yaml: Scalars['String'];
};

export type Query = {
  __typename?: 'Query';
  /** Cluster management */
  cluster?: Maybe<Apicluster>;
  replicasets?: Maybe<Array<Maybe<Replicaset>>>;
  servers?: Maybe<Array<Maybe<Server>>>;
};

export type QueryReplicasetsArgs = {
  uuid?: Maybe<Scalars['String']>;
};

export type QueryServersArgs = {
  uuid?: Maybe<Scalars['String']>;
};

/** A suggestion to reconfigure cluster topology because  one or more servers were restarted with a new advertise uri */
export type RefineUriSuggestion = {
  __typename?: 'RefineUriSuggestion';
  uri_new: Scalars['String'];
  uri_old: Scalars['String'];
  uuid: Scalars['String'];
};

/** Statistics for an instance in the replica set. */
export type ReplicaStatus = {
  __typename?: 'ReplicaStatus';
  downstream_message?: Maybe<Scalars['String']>;
  downstream_status?: Maybe<Scalars['String']>;
  id?: Maybe<Scalars['Int']>;
  lsn?: Maybe<Scalars['Long']>;
  upstream_idle?: Maybe<Scalars['Float']>;
  upstream_lag?: Maybe<Scalars['Float']>;
  upstream_message?: Maybe<Scalars['String']>;
  upstream_peer?: Maybe<Scalars['String']>;
  upstream_status?: Maybe<Scalars['String']>;
  uuid: Scalars['String'];
};

/** Group of servers replicating the same data */
export type Replicaset = {
  __typename?: 'Replicaset';
  /** The active leader. It may differ from "master" if failover is enabled and configured leader isn't healthy. */
  active_master: Server;
  /** The replica set alias */
  alias: Scalars['String'];
  /** All instances in replica set are rw */
  all_rw: Scalars['Boolean'];
  /** The leader according to the configuration. */
  master: Server;
  /** The role set enabled on every instance in the replica set */
  roles?: Maybe<Array<Scalars['String']>>;
  /** Servers in the replica set. */
  servers: Array<Server>;
  /** The replica set health. It is "healthy" if all instances have status "healthy". Otherwise "unhealthy". */
  status: Scalars['String'];
  /** The replica set uuid */
  uuid: Scalars['String'];
  /** Vshard storage group name. Meaningful only when multiple vshard groups are configured. */
  vshard_group?: Maybe<Scalars['String']>;
  /** Vshard replica set weight. Null for replica sets with vshard-storage role disabled. */
  weight?: Maybe<Scalars['Float']>;
};

/** A suggestion to restart malfunctioning replications */
export type RestartReplicationSuggestion = {
  __typename?: 'RestartReplicationSuggestion';
  uuid: Scalars['String'];
};

export type Role = {
  __typename?: 'Role';
  dependencies?: Maybe<Array<Scalars['String']>>;
  implies_router: Scalars['Boolean'];
  implies_storage: Scalars['Boolean'];
  name: Scalars['String'];
};

/** A server participating in tarantool cluster */
export type Server = {
  __typename?: 'Server';
  alias?: Maybe<Scalars['String']>;
  boxinfo?: Maybe<ServerInfo>;
  /**
   * Difference between remote clock and the current one. Obtained from the
   * membership module (SWIM protocol). Positive values mean remote clock are ahead
   * of local, and vice versa. In seconds.
   */
  clock_delta?: Maybe<Scalars['Float']>;
  disabled?: Maybe<Scalars['Boolean']>;
  labels?: Maybe<Array<Maybe<Label>>>;
  message: Scalars['String'];
  /** Failover priority within the replica set */
  priority?: Maybe<Scalars['Int']>;
  replicaset?: Maybe<Replicaset>;
  statistics?: Maybe<ServerStat>;
  status: Scalars['String'];
  uri: Scalars['String'];
  uuid: Scalars['String'];
  zone?: Maybe<Scalars['String']>;
};

/** Server information and configuration. */
export type ServerInfo = {
  __typename?: 'ServerInfo';
  cartridge: ServerInfoCartridge;
  general: ServerInfoGeneral;
  membership: ServerInfoMembership;
  network: ServerInfoNetwork;
  replication: ServerInfoReplication;
  storage: ServerInfoStorage;
  /** List of vshard router parameters */
  vshard_router?: Maybe<Array<Maybe<VshardRouter>>>;
  vshard_storage?: Maybe<ServerInfoVshardStorage>;
};

export type ServerInfoCartridge = {
  __typename?: 'ServerInfoCartridge';
  /** Error details if instance is in failure state */
  error?: Maybe<Error>;
  /** Current instance state */
  state: Scalars['String'];
  /** Cartridge version */
  version: Scalars['String'];
};

export type ServerInfoGeneral = {
  __typename?: 'ServerInfoGeneral';
  /** A globally unique identifier of the instance */
  instance_uuid: Scalars['String'];
  /** The binary protocol URI */
  listen?: Maybe<Scalars['String']>;
  /** A directory where memtx stores snapshot (.snap) files */
  memtx_dir?: Maybe<Scalars['String']>;
  /** The process ID */
  pid: Scalars['Int'];
  /** The UUID of the replica set */
  replicaset_uuid: Scalars['String'];
  /** Current read-only state */
  ro: Scalars['Boolean'];
  /** The number of seconds since the instance started */
  uptime: Scalars['Float'];
  /** The Tarantool version */
  version: Scalars['String'];
  /** A directory where vinyl files or subdirectories will be stored */
  vinyl_dir?: Maybe<Scalars['String']>;
  /** A directory where write-ahead log (.xlog) files are stored */
  wal_dir?: Maybe<Scalars['String']>;
  /** Current working directory of a process */
  work_dir?: Maybe<Scalars['String']>;
  /**
   * The maximum number of threads to use during execution of certain internal
   * processes (currently socket.getaddrinfo() and coio_call())
   */
  worker_pool_threads?: Maybe<Scalars['Int']>;
};

export type ServerInfoMembership = {
  __typename?: 'ServerInfoMembership';
  /** ACK message wait time */
  ACK_TIMEOUT_SECONDS?: Maybe<Scalars['Float']>;
  /** Anti-entropy synchronization period */
  ANTI_ENTROPY_PERIOD_SECONDS?: Maybe<Scalars['Float']>;
  /** Number of members to ping a suspect indirectly */
  NUM_FAILURE_DETECTION_SUBGROUPS?: Maybe<Scalars['Int']>;
  /** Direct ping period */
  PROTOCOL_PERIOD_SECONDS?: Maybe<Scalars['Float']>;
  /** Timeout to mark a suspect dead */
  SUSPECT_TIMEOUT_SECONDS?: Maybe<Scalars['Float']>;
  /** Value incremented every time the instance became a suspect, dead, or updates its payload */
  incarnation?: Maybe<Scalars['Int']>;
  /** Status of the instance */
  status?: Maybe<Scalars['String']>;
};

export type ServerInfoNetwork = {
  __typename?: 'ServerInfoNetwork';
  io_collect_interval?: Maybe<Scalars['Float']>;
  net_msg_max?: Maybe<Scalars['Long']>;
  readahead?: Maybe<Scalars['Long']>;
};

export type ServerInfoReplication = {
  __typename?: 'ServerInfoReplication';
  replication_connect_quorum?: Maybe<Scalars['Int']>;
  replication_connect_timeout?: Maybe<Scalars['Float']>;
  /** Statistics for all instances in the replica set in regard to the current instance */
  replication_info?: Maybe<Array<Maybe<ReplicaStatus>>>;
  replication_skip_conflict?: Maybe<Scalars['Boolean']>;
  replication_sync_lag?: Maybe<Scalars['Float']>;
  replication_sync_timeout?: Maybe<Scalars['Float']>;
  replication_timeout?: Maybe<Scalars['Float']>;
  /** The vector clock of replication log sequence numbers */
  vclock?: Maybe<Array<Maybe<Scalars['Long']>>>;
};

export type ServerInfoStorage = {
  __typename?: 'ServerInfoStorage';
  memtx_max_tuple_size?: Maybe<Scalars['Long']>;
  memtx_memory?: Maybe<Scalars['Long']>;
  memtx_min_tuple_size?: Maybe<Scalars['Long']>;
  rows_per_wal?: Maybe<Scalars['Long']>;
  too_long_threshold?: Maybe<Scalars['Float']>;
  vinyl_bloom_fpr?: Maybe<Scalars['Float']>;
  vinyl_cache?: Maybe<Scalars['Long']>;
  vinyl_max_tuple_size?: Maybe<Scalars['Long']>;
  vinyl_memory?: Maybe<Scalars['Long']>;
  vinyl_page_size?: Maybe<Scalars['Long']>;
  vinyl_range_size?: Maybe<Scalars['Long']>;
  vinyl_read_threads?: Maybe<Scalars['Int']>;
  vinyl_run_count_per_level?: Maybe<Scalars['Int']>;
  vinyl_run_size_ratio?: Maybe<Scalars['Float']>;
  vinyl_timeout?: Maybe<Scalars['Float']>;
  vinyl_write_threads?: Maybe<Scalars['Int']>;
  wal_dir_rescan_delay?: Maybe<Scalars['Float']>;
  wal_max_size?: Maybe<Scalars['Long']>;
  wal_mode?: Maybe<Scalars['String']>;
};

export type ServerInfoVshardStorage = {
  __typename?: 'ServerInfoVshardStorage';
  /** The number of active buckets on the storage */
  buckets_active?: Maybe<Scalars['Int']>;
  /** The number of buckets that are waiting to be collected by GC */
  buckets_garbage?: Maybe<Scalars['Int']>;
  /** The number of pinned buckets on the storage */
  buckets_pinned?: Maybe<Scalars['Int']>;
  /** The number of buckets that are receiving at this time */
  buckets_receiving?: Maybe<Scalars['Int']>;
  /** The number of buckets that are sending at this time */
  buckets_sending?: Maybe<Scalars['Int']>;
  /** Total number of buckets on the storage */
  buckets_total?: Maybe<Scalars['Int']>;
  /** Vshard group */
  vshard_group?: Maybe<Scalars['String']>;
};

/** A short server information */
export type ServerShortInfo = {
  __typename?: 'ServerShortInfo';
  alias?: Maybe<Scalars['String']>;
  app_name?: Maybe<Scalars['String']>;
  demo_uri?: Maybe<Scalars['String']>;
  error?: Maybe<Scalars['String']>;
  instance_name?: Maybe<Scalars['String']>;
  state?: Maybe<Scalars['String']>;
  uri: Scalars['String'];
  uuid?: Maybe<Scalars['String']>;
};

/** Slab allocator statistics. This can be used to monitor the total memory usage (in bytes) and memory fragmentation. */
export type ServerStat = {
  __typename?: 'ServerStat';
  /** The total memory used for tuples and indexes together (including allocated, but currently free slabs) */
  arena_size: Scalars['Long'];
  /** The efficient memory used for storing tuples and indexes together (omitting allocated, but currently free slabs) */
  arena_used: Scalars['Long'];
  /** = arena_used / arena_size */
  arena_used_ratio: Scalars['String'];
  /** The total amount of memory (including allocated, but currently free slabs) used only for tuples, no indexes */
  items_size: Scalars['Long'];
  /** The efficient amount of memory (omitting allocated, but currently free slabs) used only for tuples, no indexes */
  items_used: Scalars['Long'];
  /** = items_used / slab_count * slab_size (these are slabs used only for tuples, no indexes) */
  items_used_ratio: Scalars['String'];
  /**
   * The maximum amount of memory that the slab allocator can use for both tuples
   * and indexes (as configured in the memtx_memory parameter)
   */
  quota_size: Scalars['Long'];
  /** The amount of memory that is already distributed to the slab allocator */
  quota_used: Scalars['Long'];
  /** = quota_used / quota_size */
  quota_used_ratio: Scalars['String'];
  /** Number of buckets active on the storage */
  vshard_buckets_count?: Maybe<Scalars['Int']>;
};

export type Suggestions = {
  __typename?: 'Suggestions';
  disable_servers?: Maybe<Array<DisableServerSuggestion>>;
  force_apply?: Maybe<Array<ForceApplySuggestion>>;
  refine_uri?: Maybe<Array<RefineUriSuggestion>>;
  restart_replication?: Maybe<Array<RestartReplicationSuggestion>>;
};

/** A single user account information */
export type User = {
  __typename?: 'User';
  email?: Maybe<Scalars['String']>;
  fullname?: Maybe<Scalars['String']>;
  username: Scalars['String'];
};

/** User managent parameters and available operations */
export type UserManagementApi = {
  __typename?: 'UserManagementAPI';
  /** Number of seconds until the authentication cookie expires. */
  cookie_max_age: Scalars['Long'];
  /** Update provided cookie if it's older then this age. */
  cookie_renew_age: Scalars['Long'];
  /** Whether authentication is enabled. */
  enabled: Scalars['Boolean'];
  implements_add_user: Scalars['Boolean'];
  implements_check_password: Scalars['Boolean'];
  implements_edit_user: Scalars['Boolean'];
  implements_get_user: Scalars['Boolean'];
  implements_list_users: Scalars['Boolean'];
  implements_remove_user: Scalars['Boolean'];
  /** Active session username. */
  username?: Maybe<Scalars['String']>;
};

/** Result of config validation */
export type ValidateConfigResult = {
  __typename?: 'ValidateConfigResult';
  /** Error details if validation fails, null otherwise */
  error?: Maybe<Scalars['String']>;
};

/** Group of replicasets sharding the same dataset */
export type VshardGroup = {
  __typename?: 'VshardGroup';
  /** Whether the group is ready to operate */
  bootstrapped: Scalars['Boolean'];
  /** Virtual buckets count in the group */
  bucket_count: Scalars['Int'];
  /** If set to true, the Lua collectgarbage() function is called periodically */
  collect_lua_garbage: Scalars['Boolean'];
  /** Group name */
  name: Scalars['String'];
  /** A maximum bucket disbalance threshold, in percent */
  rebalancer_disbalance_threshold: Scalars['Float'];
  /** The maximum number of buckets that can be received in parallel by a single replica set in the storage group */
  rebalancer_max_receiving: Scalars['Int'];
  /** The maximum number of buckets that can be sent in parallel by a single replica set in the storage group */
  rebalancer_max_sending: Scalars['Int'];
  /** Scheduler bucket move quota */
  sched_move_quota: Scalars['Long'];
  /** Scheduler storage ref quota */
  sched_ref_quota: Scalars['Long'];
  /** Timeout to wait for synchronization of the old master with replicas before demotion */
  sync_timeout: Scalars['Float'];
};

export type VshardRouter = {
  __typename?: 'VshardRouter';
  /** The number of buckets known to the router and available for read requests */
  buckets_available_ro?: Maybe<Scalars['Int']>;
  /** The number of buckets known to the router and available for read and write requests */
  buckets_available_rw?: Maybe<Scalars['Int']>;
  /** The number of buckets whose replica sets are not known to the router */
  buckets_unknown?: Maybe<Scalars['Int']>;
  /** The number of buckets known to the router but unavailable for any requests */
  buckets_unreachable?: Maybe<Scalars['Int']>;
  /** Vshard group */
  vshard_group?: Maybe<Scalars['String']>;
};

/** One possible value for a given Enum. Enum values are unique values, not a placeholder for a string or numeric value. However an Enum value is returned in a JSON response as a string. */
export type __EnumValue = {
  __typename?: '__EnumValue';
  name: Scalars['String'];
  description?: Maybe<Scalars['String']>;
  isDeprecated: Scalars['Boolean'];
  deprecationReason?: Maybe<Scalars['String']>;
};

/** Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type. */
export type __Field = {
  __typename?: '__Field';
  name: Scalars['String'];
  description?: Maybe<Scalars['String']>;
  args: Array<__InputValue>;
  type: __Type;
  isDeprecated: Scalars['Boolean'];
  deprecationReason?: Maybe<Scalars['String']>;
};

/** Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type. */
export type __FieldArgsArgs = {
  includeDeprecated?: Maybe<Scalars['Boolean']>;
};

/** Arguments provided to Fields or Directives and the input fields of an InputObject are represented as Input Values which describe their type and optionally a default value. */
export type __InputValue = {
  __typename?: '__InputValue';
  name: Scalars['String'];
  description?: Maybe<Scalars['String']>;
  type: __Type;
  /** A GraphQL-formatted string representing the default value for this input value. */
  defaultValue?: Maybe<Scalars['String']>;
  isDeprecated: Scalars['Boolean'];
  deprecationReason?: Maybe<Scalars['String']>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __Type = {
  __typename?: '__Type';
  kind: __TypeKind;
  name?: Maybe<Scalars['String']>;
  description?: Maybe<Scalars['String']>;
  specifiedByUrl?: Maybe<Scalars['String']>;
  fields?: Maybe<Array<__Field>>;
  interfaces?: Maybe<Array<__Type>>;
  possibleTypes?: Maybe<Array<__Type>>;
  enumValues?: Maybe<Array<__EnumValue>>;
  inputFields?: Maybe<Array<__InputValue>>;
  ofType?: Maybe<__Type>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __TypeFieldsArgs = {
  includeDeprecated?: Maybe<Scalars['Boolean']>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __TypeEnumValuesArgs = {
  includeDeprecated?: Maybe<Scalars['Boolean']>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __TypeInputFieldsArgs = {
  includeDeprecated?: Maybe<Scalars['Boolean']>;
};

/** An enum describing what kind of type a given `__Type` is. */
export enum __TypeKind {
  /** Indicates this type is a scalar. */
  Scalar = 'SCALAR',
  /** Indicates this type is an object. `fields` and `interfaces` are valid fields. */
  Object = 'OBJECT',
  /** Indicates this type is an interface. `fields`, `interfaces`, and `possibleTypes` are valid fields. */
  Interface = 'INTERFACE',
  /** Indicates this type is a union. `possibleTypes` is a valid field. */
  Union = 'UNION',
  /** Indicates this type is an enum. `enumValues` is a valid field. */
  Enum = 'ENUM',
  /** Indicates this type is an input object. `inputFields` is a valid field. */
  InputObject = 'INPUT_OBJECT',
  /** Indicates this type is a list. `ofType` is a valid field. */
  List = 'LIST',
  /** Indicates this type is a non-null. `ofType` is a valid field. */
  NonNull = 'NON_NULL',
}

export type ServerStatFieldsFragment = {
  __typename?: 'Server';
  uuid: string;
  uri: string;
  statistics?: Maybe<{
    __typename?: 'ServerStat';
    quota_used_ratio: string;
    arena_used_ratio: string;
    items_used_ratio: string;
    quotaSize: number;
    arenaUsed: number;
    bucketsCount?: Maybe<number>;
  }>;
};

export type AuthQueryVariables = Exact<{ [key: string]: never }>;

export type AuthQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    authParams: { __typename?: 'UserManagementAPI'; enabled: boolean; username?: Maybe<string> };
  }>;
};

export type TurnAuthMutationVariables = Exact<{
  enabled?: Maybe<Scalars['Boolean']>;
}>;

export type TurnAuthMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    authParams: { __typename?: 'UserManagementAPI'; enabled: boolean };
  }>;
};

export type GetClusterQueryVariables = Exact<{ [key: string]: never }>;

export type GetClusterQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    can_bootstrap_vshard: boolean;
    vshard_bucket_count: number;
    MenuBlacklist?: Maybe<Array<string>>;
    clusterSelf?: Maybe<{
      __typename?: 'ServerShortInfo';
      app_name?: Maybe<string>;
      instance_name?: Maybe<string>;
      demo_uri?: Maybe<string>;
      uri: string;
      uuid?: Maybe<string>;
    }>;
    failover_params: {
      __typename?: 'FailoverAPI';
      failover_timeout: number;
      fencing_enabled: boolean;
      fencing_timeout: number;
      fencing_pause: number;
      mode: string;
      state_provider?: Maybe<string>;
      etcd2_params?: Maybe<{
        __typename?: 'FailoverStateProviderCfgEtcd2';
        password: string;
        lock_delay: number;
        endpoints: Array<string>;
        username: string;
        prefix: string;
      }>;
      tarantool_params?: Maybe<{ __typename?: 'FailoverStateProviderCfgTarantool'; uri: string; password: string }>;
    };
    knownRoles: Array<{
      __typename?: 'Role';
      name: string;
      dependencies?: Maybe<Array<string>>;
      implies_storage: boolean;
      implies_router: boolean;
    }>;
    vshard_groups: Array<{ __typename?: 'VshardGroup'; name: string; bucket_count: number; bootstrapped: boolean }>;
    authParams: {
      __typename?: 'UserManagementAPI';
      enabled: boolean;
      implements_add_user: boolean;
      implements_check_password: boolean;
      implements_list_users: boolean;
      implements_edit_user: boolean;
      implements_remove_user: boolean;
      username?: Maybe<string>;
    };
  }>;
};

export type ServerDetailsFieldsFragment = {
  __typename?: 'Server';
  alias?: Maybe<string>;
  status: string;
  message: string;
  uri: string;
  replicaset?: Maybe<{
    __typename?: 'Replicaset';
    roles?: Maybe<Array<string>>;
    active_master: { __typename?: 'Server'; uuid: string };
    master: { __typename?: 'Server'; uuid: string };
  }>;
  labels?: Maybe<Array<Maybe<{ __typename?: 'Label'; name: string; value: string }>>>;
  boxinfo?: Maybe<{
    __typename?: 'ServerInfo';
    cartridge: { __typename?: 'ServerInfoCartridge'; version: string };
    membership: {
      __typename?: 'ServerInfoMembership';
      status?: Maybe<string>;
      incarnation?: Maybe<number>;
      PROTOCOL_PERIOD_SECONDS?: Maybe<number>;
      ACK_TIMEOUT_SECONDS?: Maybe<number>;
      ANTI_ENTROPY_PERIOD_SECONDS?: Maybe<number>;
      SUSPECT_TIMEOUT_SECONDS?: Maybe<number>;
      NUM_FAILURE_DETECTION_SUBGROUPS?: Maybe<number>;
    };
    vshard_router?: Maybe<
      Array<
        Maybe<{
          __typename?: 'VshardRouter';
          vshard_group?: Maybe<string>;
          buckets_unreachable?: Maybe<number>;
          buckets_available_ro?: Maybe<number>;
          buckets_unknown?: Maybe<number>;
          buckets_available_rw?: Maybe<number>;
        }>
      >
    >;
    vshard_storage?: Maybe<{
      __typename?: 'ServerInfoVshardStorage';
      vshard_group?: Maybe<string>;
      buckets_receiving?: Maybe<number>;
      buckets_active?: Maybe<number>;
      buckets_total?: Maybe<number>;
      buckets_garbage?: Maybe<number>;
      buckets_pinned?: Maybe<number>;
      buckets_sending?: Maybe<number>;
    }>;
    network: {
      __typename?: 'ServerInfoNetwork';
      io_collect_interval?: Maybe<number>;
      net_msg_max?: Maybe<number>;
      readahead?: Maybe<number>;
    };
    general: { __typename?: 'ServerInfoGeneral'; instance_uuid: string; uptime: number; version: string; ro: boolean };
    replication: {
      __typename?: 'ServerInfoReplication';
      replication_connect_quorum?: Maybe<number>;
      replication_connect_timeout?: Maybe<number>;
      replication_sync_timeout?: Maybe<number>;
      replication_skip_conflict?: Maybe<boolean>;
      replication_sync_lag?: Maybe<number>;
      vclock?: Maybe<Array<Maybe<number>>>;
      replication_timeout?: Maybe<number>;
      replication_info?: Maybe<
        Array<
          Maybe<{
            __typename?: 'ReplicaStatus';
            downstream_status?: Maybe<string>;
            id?: Maybe<number>;
            upstream_peer?: Maybe<string>;
            upstream_idle?: Maybe<number>;
            upstream_message?: Maybe<string>;
            lsn?: Maybe<number>;
            upstream_lag?: Maybe<number>;
            upstream_status?: Maybe<string>;
            uuid: string;
            downstream_message?: Maybe<string>;
          }>
        >
      >;
    };
    storage: {
      __typename?: 'ServerInfoStorage';
      wal_max_size?: Maybe<number>;
      vinyl_run_count_per_level?: Maybe<number>;
      rows_per_wal?: Maybe<number>;
      vinyl_cache?: Maybe<number>;
      vinyl_range_size?: Maybe<number>;
      vinyl_timeout?: Maybe<number>;
      memtx_min_tuple_size?: Maybe<number>;
      vinyl_bloom_fpr?: Maybe<number>;
      vinyl_page_size?: Maybe<number>;
      memtx_max_tuple_size?: Maybe<number>;
      vinyl_run_size_ratio?: Maybe<number>;
      wal_mode?: Maybe<string>;
      memtx_memory?: Maybe<number>;
      vinyl_memory?: Maybe<number>;
      too_long_threshold?: Maybe<number>;
      vinyl_max_tuple_size?: Maybe<number>;
      vinyl_write_threads?: Maybe<number>;
      vinyl_read_threads?: Maybe<number>;
      wal_dir_rescan_delay?: Maybe<number>;
    };
  }>;
};

export type InstanceDataQueryVariables = Exact<{
  uuid?: Maybe<Scalars['String']>;
}>;

export type InstanceDataQuery = {
  __typename?: 'Query';
  servers?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Server';
        alias?: Maybe<string>;
        status: string;
        message: string;
        uri: string;
        replicaset?: Maybe<{
          __typename?: 'Replicaset';
          roles?: Maybe<Array<string>>;
          active_master: { __typename?: 'Server'; uuid: string };
          master: { __typename?: 'Server'; uuid: string };
        }>;
        labels?: Maybe<Array<Maybe<{ __typename?: 'Label'; name: string; value: string }>>>;
        boxinfo?: Maybe<{
          __typename?: 'ServerInfo';
          cartridge: { __typename?: 'ServerInfoCartridge'; version: string };
          membership: {
            __typename?: 'ServerInfoMembership';
            status?: Maybe<string>;
            incarnation?: Maybe<number>;
            PROTOCOL_PERIOD_SECONDS?: Maybe<number>;
            ACK_TIMEOUT_SECONDS?: Maybe<number>;
            ANTI_ENTROPY_PERIOD_SECONDS?: Maybe<number>;
            SUSPECT_TIMEOUT_SECONDS?: Maybe<number>;
            NUM_FAILURE_DETECTION_SUBGROUPS?: Maybe<number>;
          };
          vshard_router?: Maybe<
            Array<
              Maybe<{
                __typename?: 'VshardRouter';
                vshard_group?: Maybe<string>;
                buckets_unreachable?: Maybe<number>;
                buckets_available_ro?: Maybe<number>;
                buckets_unknown?: Maybe<number>;
                buckets_available_rw?: Maybe<number>;
              }>
            >
          >;
          vshard_storage?: Maybe<{
            __typename?: 'ServerInfoVshardStorage';
            vshard_group?: Maybe<string>;
            buckets_receiving?: Maybe<number>;
            buckets_active?: Maybe<number>;
            buckets_total?: Maybe<number>;
            buckets_garbage?: Maybe<number>;
            buckets_pinned?: Maybe<number>;
            buckets_sending?: Maybe<number>;
          }>;
          network: {
            __typename?: 'ServerInfoNetwork';
            io_collect_interval?: Maybe<number>;
            net_msg_max?: Maybe<number>;
            readahead?: Maybe<number>;
          };
          general: {
            __typename?: 'ServerInfoGeneral';
            instance_uuid: string;
            uptime: number;
            version: string;
            ro: boolean;
          };
          replication: {
            __typename?: 'ServerInfoReplication';
            replication_connect_quorum?: Maybe<number>;
            replication_connect_timeout?: Maybe<number>;
            replication_sync_timeout?: Maybe<number>;
            replication_skip_conflict?: Maybe<boolean>;
            replication_sync_lag?: Maybe<number>;
            vclock?: Maybe<Array<Maybe<number>>>;
            replication_timeout?: Maybe<number>;
            replication_info?: Maybe<
              Array<
                Maybe<{
                  __typename?: 'ReplicaStatus';
                  downstream_status?: Maybe<string>;
                  id?: Maybe<number>;
                  upstream_peer?: Maybe<string>;
                  upstream_idle?: Maybe<number>;
                  upstream_message?: Maybe<string>;
                  lsn?: Maybe<number>;
                  upstream_lag?: Maybe<number>;
                  upstream_status?: Maybe<string>;
                  uuid: string;
                  downstream_message?: Maybe<string>;
                }>
              >
            >;
          };
          storage: {
            __typename?: 'ServerInfoStorage';
            wal_max_size?: Maybe<number>;
            vinyl_run_count_per_level?: Maybe<number>;
            rows_per_wal?: Maybe<number>;
            vinyl_cache?: Maybe<number>;
            vinyl_range_size?: Maybe<number>;
            vinyl_timeout?: Maybe<number>;
            memtx_min_tuple_size?: Maybe<number>;
            vinyl_bloom_fpr?: Maybe<number>;
            vinyl_page_size?: Maybe<number>;
            memtx_max_tuple_size?: Maybe<number>;
            vinyl_run_size_ratio?: Maybe<number>;
            wal_mode?: Maybe<string>;
            memtx_memory?: Maybe<number>;
            vinyl_memory?: Maybe<number>;
            too_long_threshold?: Maybe<number>;
            vinyl_max_tuple_size?: Maybe<number>;
            vinyl_write_threads?: Maybe<number>;
            vinyl_read_threads?: Maybe<number>;
            wal_dir_rescan_delay?: Maybe<number>;
          };
        }>;
      }>
    >
  >;
  descriptionCartridge?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionMembership?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionVshardRouter?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionVshardStorage?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionGeneral?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionNetwork?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionReplication?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
  descriptionStorage?: Maybe<{
    __typename?: '__Type';
    fields?: Maybe<Array<{ __typename?: '__Field'; name: string; description?: Maybe<string> }>>;
  }>;
};

export type BoxInfoQueryVariables = Exact<{
  uuid?: Maybe<Scalars['String']>;
}>;

export type BoxInfoQuery = {
  __typename?: 'Query';
  servers?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Server';
        alias?: Maybe<string>;
        status: string;
        message: string;
        uri: string;
        replicaset?: Maybe<{
          __typename?: 'Replicaset';
          roles?: Maybe<Array<string>>;
          active_master: { __typename?: 'Server'; uuid: string };
          master: { __typename?: 'Server'; uuid: string };
        }>;
        labels?: Maybe<Array<Maybe<{ __typename?: 'Label'; name: string; value: string }>>>;
        boxinfo?: Maybe<{
          __typename?: 'ServerInfo';
          cartridge: { __typename?: 'ServerInfoCartridge'; version: string };
          membership: {
            __typename?: 'ServerInfoMembership';
            status?: Maybe<string>;
            incarnation?: Maybe<number>;
            PROTOCOL_PERIOD_SECONDS?: Maybe<number>;
            ACK_TIMEOUT_SECONDS?: Maybe<number>;
            ANTI_ENTROPY_PERIOD_SECONDS?: Maybe<number>;
            SUSPECT_TIMEOUT_SECONDS?: Maybe<number>;
            NUM_FAILURE_DETECTION_SUBGROUPS?: Maybe<number>;
          };
          vshard_router?: Maybe<
            Array<
              Maybe<{
                __typename?: 'VshardRouter';
                vshard_group?: Maybe<string>;
                buckets_unreachable?: Maybe<number>;
                buckets_available_ro?: Maybe<number>;
                buckets_unknown?: Maybe<number>;
                buckets_available_rw?: Maybe<number>;
              }>
            >
          >;
          vshard_storage?: Maybe<{
            __typename?: 'ServerInfoVshardStorage';
            vshard_group?: Maybe<string>;
            buckets_receiving?: Maybe<number>;
            buckets_active?: Maybe<number>;
            buckets_total?: Maybe<number>;
            buckets_garbage?: Maybe<number>;
            buckets_pinned?: Maybe<number>;
            buckets_sending?: Maybe<number>;
          }>;
          network: {
            __typename?: 'ServerInfoNetwork';
            io_collect_interval?: Maybe<number>;
            net_msg_max?: Maybe<number>;
            readahead?: Maybe<number>;
          };
          general: {
            __typename?: 'ServerInfoGeneral';
            instance_uuid: string;
            uptime: number;
            version: string;
            ro: boolean;
          };
          replication: {
            __typename?: 'ServerInfoReplication';
            replication_connect_quorum?: Maybe<number>;
            replication_connect_timeout?: Maybe<number>;
            replication_sync_timeout?: Maybe<number>;
            replication_skip_conflict?: Maybe<boolean>;
            replication_sync_lag?: Maybe<number>;
            vclock?: Maybe<Array<Maybe<number>>>;
            replication_timeout?: Maybe<number>;
            replication_info?: Maybe<
              Array<
                Maybe<{
                  __typename?: 'ReplicaStatus';
                  downstream_status?: Maybe<string>;
                  id?: Maybe<number>;
                  upstream_peer?: Maybe<string>;
                  upstream_idle?: Maybe<number>;
                  upstream_message?: Maybe<string>;
                  lsn?: Maybe<number>;
                  upstream_lag?: Maybe<number>;
                  upstream_status?: Maybe<string>;
                  uuid: string;
                  downstream_message?: Maybe<string>;
                }>
              >
            >;
          };
          storage: {
            __typename?: 'ServerInfoStorage';
            wal_max_size?: Maybe<number>;
            vinyl_run_count_per_level?: Maybe<number>;
            rows_per_wal?: Maybe<number>;
            vinyl_cache?: Maybe<number>;
            vinyl_range_size?: Maybe<number>;
            vinyl_timeout?: Maybe<number>;
            memtx_min_tuple_size?: Maybe<number>;
            vinyl_bloom_fpr?: Maybe<number>;
            vinyl_page_size?: Maybe<number>;
            memtx_max_tuple_size?: Maybe<number>;
            vinyl_run_size_ratio?: Maybe<number>;
            wal_mode?: Maybe<string>;
            memtx_memory?: Maybe<number>;
            vinyl_memory?: Maybe<number>;
            too_long_threshold?: Maybe<number>;
            vinyl_max_tuple_size?: Maybe<number>;
            vinyl_write_threads?: Maybe<number>;
            vinyl_read_threads?: Maybe<number>;
            wal_dir_rescan_delay?: Maybe<number>;
          };
        }>;
      }>
    >
  >;
};

export type ServerListQueryVariables = Exact<{
  withStats: Scalars['Boolean'];
}>;

export type ServerListQuery = {
  __typename?: 'Query';
  failover?: Maybe<{ __typename?: 'Apicluster'; failover_params: { __typename?: 'FailoverAPI'; mode: string } }>;
  serverList?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Server';
        uuid: string;
        alias?: Maybe<string>;
        disabled?: Maybe<boolean>;
        uri: string;
        zone?: Maybe<string>;
        status: string;
        message: string;
        boxinfo?: Maybe<{ __typename?: 'ServerInfo'; general: { __typename?: 'ServerInfoGeneral'; ro: boolean } }>;
        replicaset?: Maybe<{ __typename?: 'Replicaset'; uuid: string }>;
      }>
    >
  >;
  replicasetList?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Replicaset';
        alias: string;
        all_rw: boolean;
        uuid: string;
        status: string;
        roles?: Maybe<Array<string>>;
        vshard_group?: Maybe<string>;
        weight?: Maybe<number>;
        master: { __typename?: 'Server'; uuid: string };
        active_master: { __typename?: 'Server'; uuid: string };
        servers: Array<{
          __typename?: 'Server';
          uuid: string;
          alias?: Maybe<string>;
          disabled?: Maybe<boolean>;
          uri: string;
          priority?: Maybe<number>;
          status: string;
          message: string;
          boxinfo?: Maybe<{ __typename?: 'ServerInfo'; general: { __typename?: 'ServerInfoGeneral'; ro: boolean } }>;
          replicaset?: Maybe<{ __typename?: 'Replicaset'; uuid: string }>;
        }>;
      }>
    >
  >;
  serverStat?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Server';
        uuid: string;
        uri: string;
        statistics?: Maybe<{
          __typename?: 'ServerStat';
          quota_used_ratio: string;
          arena_used_ratio: string;
          items_used_ratio: string;
          quotaSize: number;
          arenaUsed: number;
          bucketsCount?: Maybe<number>;
        }>;
      }>
    >
  >;
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    suggestions?: Maybe<{
      __typename?: 'Suggestions';
      disable_servers?: Maybe<Array<{ __typename?: 'DisableServerSuggestion'; uuid: string }>>;
      restart_replication?: Maybe<Array<{ __typename?: 'RestartReplicationSuggestion'; uuid: string }>>;
      force_apply?: Maybe<
        Array<{
          __typename?: 'ForceApplySuggestion';
          config_mismatch: boolean;
          config_locked: boolean;
          uuid: string;
          operation_error: boolean;
        }>
      >;
      refine_uri?: Maybe<Array<{ __typename?: 'RefineUriSuggestion'; uuid: string; uri_old: string; uri_new: string }>>;
    }>;
    issues?: Maybe<
      Array<{
        __typename?: 'Issue';
        level: string;
        replicaset_uuid?: Maybe<string>;
        instance_uuid?: Maybe<string>;
        message: string;
        topic: string;
      }>
    >;
  }>;
};

export type ServerStatQueryVariables = Exact<{ [key: string]: never }>;

export type ServerStatQuery = {
  __typename?: 'Query';
  serverStat?: Maybe<
    Array<
      Maybe<{
        __typename?: 'Server';
        uuid: string;
        uri: string;
        statistics?: Maybe<{
          __typename?: 'ServerStat';
          quota_used_ratio: string;
          arena_used_ratio: string;
          items_used_ratio: string;
          quotaSize: number;
          arenaUsed: number;
          bucketsCount?: Maybe<number>;
        }>;
      }>
    >
  >;
};

export type BootstrapMutationVariables = Exact<{ [key: string]: never }>;

export type BootstrapMutation = { __typename?: 'Mutation'; bootstrapVshardResponse?: Maybe<boolean> };

export type ProbeMutationVariables = Exact<{
  uri: Scalars['String'];
}>;

export type ProbeMutation = { __typename?: 'Mutation'; probeServerResponse?: Maybe<boolean> };

export type EditTopologyMutationVariables = Exact<{
  replicasets?: Maybe<Array<EditReplicasetInput> | EditReplicasetInput>;
  servers?: Maybe<Array<EditServerInput> | EditServerInput>;
}>;

export type EditTopologyMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    edit_topology?: Maybe<{
      __typename?: 'EditTopologyResult';
      servers: Array<Maybe<{ __typename?: 'Server'; uuid: string }>>;
    }>;
  }>;
};

export type ChangeFailoverMutationVariables = Exact<{
  failover_timeout?: Maybe<Scalars['Float']>;
  fencing_enabled?: Maybe<Scalars['Boolean']>;
  fencing_timeout?: Maybe<Scalars['Float']>;
  fencing_pause?: Maybe<Scalars['Float']>;
  mode: Scalars['String'];
  state_provider?: Maybe<Scalars['String']>;
  etcd2_params?: Maybe<FailoverStateProviderCfgInputEtcd2>;
  tarantool_params?: Maybe<FailoverStateProviderCfgInputTarantool>;
}>;

export type ChangeFailoverMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{ __typename?: 'MutationApicluster'; failover_params: { __typename?: 'FailoverAPI'; mode: string } }>;
};

export type PromoteFailoverLeaderMutationVariables = Exact<{
  replicaset_uuid: Scalars['String'];
  instance_uuid: Scalars['String'];
  force_inconsistency?: Maybe<Scalars['Boolean']>;
}>;

export type PromoteFailoverLeaderMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{ __typename?: 'MutationApicluster'; failover_promote: boolean }>;
};

export type FetchUsersQueryVariables = Exact<{ [key: string]: never }>;

export type FetchUsersQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    users?: Maybe<Array<{ __typename?: 'User'; username: string; fullname?: Maybe<string>; email?: Maybe<string> }>>;
  }>;
};

export type AddUserMutationVariables = Exact<{
  username: Scalars['String'];
  password: Scalars['String'];
  email: Scalars['String'];
  fullname: Scalars['String'];
}>;

export type AddUserMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    add_user?: Maybe<{ __typename?: 'User'; username: string; email?: Maybe<string>; fullname?: Maybe<string> }>;
  }>;
};

export type EditUserMutationVariables = Exact<{
  username: Scalars['String'];
  password?: Maybe<Scalars['String']>;
  email?: Maybe<Scalars['String']>;
  fullname?: Maybe<Scalars['String']>;
}>;

export type EditUserMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    edit_user?: Maybe<{ __typename?: 'User'; username: string; email?: Maybe<string>; fullname?: Maybe<string> }>;
  }>;
};

export type RemoveUserMutationVariables = Exact<{
  username: Scalars['String'];
}>;

export type RemoveUserMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    remove_user?: Maybe<{ __typename?: 'User'; username: string; email?: Maybe<string>; fullname?: Maybe<string> }>;
  }>;
};

export type Set_FilesMutationVariables = Exact<{
  files?: Maybe<Array<ConfigSectionInput> | ConfigSectionInput>;
}>;

export type Set_FilesMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    config: Array<Maybe<{ __typename?: 'ConfigSection'; filename: string; content: string }>>;
  }>;
};

export type Disable_ServersMutationVariables = Exact<{
  uuids?: Maybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Disable_ServersMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{
    __typename?: 'MutationApicluster';
    disable_servers?: Maybe<Array<Maybe<{ __typename?: 'Server'; uuid: string; disabled?: Maybe<boolean> }>>>;
  }>;
};

export type Restart_ReplicationMutationVariables = Exact<{
  uuids?: Maybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Restart_ReplicationMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{ __typename?: 'MutationApicluster'; restart_replication?: Maybe<boolean> }>;
};

export type Config_Force_ReapplyMutationVariables = Exact<{
  uuids?: Maybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Config_Force_ReapplyMutation = {
  __typename?: 'Mutation';
  cluster?: Maybe<{ __typename?: 'MutationApicluster'; config_force_reapply: boolean }>;
};

export type ConfigFilesQueryVariables = Exact<{ [key: string]: never }>;

export type ConfigFilesQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    config: Array<Maybe<{ __typename?: 'ConfigSection'; content: string; path: string }>>;
  }>;
};

export type GetFailoverParamsQueryVariables = Exact<{ [key: string]: never }>;

export type GetFailoverParamsQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    failover_params: {
      __typename?: 'FailoverAPI';
      failover_timeout: number;
      fencing_enabled: boolean;
      fencing_timeout: number;
      fencing_pause: number;
      mode: string;
      state_provider?: Maybe<string>;
      etcd2_params?: Maybe<{
        __typename?: 'FailoverStateProviderCfgEtcd2';
        password: string;
        lock_delay: number;
        endpoints: Array<string>;
        username: string;
        prefix: string;
      }>;
      tarantool_params?: Maybe<{ __typename?: 'FailoverStateProviderCfgTarantool'; uri: string; password: string }>;
    };
  }>;
};

export type ValidateConfigQueryVariables = Exact<{
  sections?: Maybe<Array<ConfigSectionInput> | ConfigSectionInput>;
}>;

export type ValidateConfigQuery = {
  __typename?: 'Query';
  cluster?: Maybe<{
    __typename?: 'Apicluster';
    validate_config: { __typename?: 'ValidateConfigResult'; error?: Maybe<string> };
  }>;
};
