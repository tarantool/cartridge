export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
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
  /** compression info about cluster */
  cluster_compression: ClusterCompressionInfo;
  /** Get cluster config sections */
  config: Array<Maybe<ConfigSection>>;
  /** Get current failover state. (Deprecated since v2.0.2-2) */
  failover: Scalars['Boolean'];
  /** Get automatic failover configuration. */
  failover_params: FailoverApi;
  /** Get state provider status. */
  failover_state_provider_status: Array<Maybe<StateProviderStatus>>;
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
  sections?: InputMaybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type ApiclusterUsersArgs = {
  username?: InputMaybe<Scalars['String']>;
};

/** Cluster management */
export type ApiclusterValidate_ConfigArgs = {
  sections?: InputMaybe<Array<InputMaybe<ConfigSectionInput>>>;
};

/** Compression info of all cluster instances */
export type ClusterCompressionInfo = {
  __typename?: 'ClusterCompressionInfo';
  /** cluster compression info */
  compression_info: Array<InstanceCompressionInfo>;
};

/** A section of clusterwide configuration */
export type ConfigSection = {
  __typename?: 'ConfigSection';
  content: Scalars['String'];
  filename: Scalars['String'];
};

/** A section of clusterwide configuration */
export type ConfigSectionInput = {
  content?: InputMaybe<Scalars['String']>;
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
  alias?: InputMaybe<Scalars['String']>;
  all_rw?: InputMaybe<Scalars['Boolean']>;
  failover_priority?: InputMaybe<Array<Scalars['String']>>;
  join_servers?: InputMaybe<Array<InputMaybe<JoinServerInput>>>;
  rebalancer?: InputMaybe<Scalars['Boolean']>;
  roles?: InputMaybe<Array<Scalars['String']>>;
  uuid?: InputMaybe<Scalars['String']>;
  vshard_group?: InputMaybe<Scalars['String']>;
  weight?: InputMaybe<Scalars['Float']>;
};

/** Parameters for editing existing server */
export type EditServerInput = {
  disabled?: InputMaybe<Scalars['Boolean']>;
  electable?: InputMaybe<Scalars['Boolean']>;
  expelled?: InputMaybe<Scalars['Boolean']>;
  labels?: InputMaybe<Array<InputMaybe<LabelInput>>>;
  rebalancer?: InputMaybe<Scalars['Boolean']>;
  uri?: InputMaybe<Scalars['String']>;
  uuid: Scalars['String'];
  zone?: InputMaybe<Scalars['String']>;
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
  autoreturn_delay: Scalars['Float'];
  check_cookie_hash: Scalars['Boolean'];
  etcd2_params?: Maybe<FailoverStateProviderCfgEtcd2>;
  failover_timeout: Scalars['Float'];
  fencing_enabled: Scalars['Boolean'];
  fencing_pause: Scalars['Float'];
  fencing_timeout: Scalars['Float'];
  leader_autoreturn: Scalars['Boolean'];
  /** Supported modes are "disabled", "eventual", "stateful" or "raft". */
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
  endpoints?: InputMaybe<Array<Scalars['String']>>;
  lock_delay?: InputMaybe<Scalars['Float']>;
  password?: InputMaybe<Scalars['String']>;
  prefix?: InputMaybe<Scalars['String']>;
  username?: InputMaybe<Scalars['String']>;
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

/** Information about single field compression rate possibility */
export type FieldCompressionInfo = {
  __typename?: 'FieldCompressionInfo';
  /** compression percentage */
  compression_percentage: Scalars['Int'];
  /** compression time */
  compression_time: Scalars['Int'];
  /** field name */
  field_name: Scalars['String'];
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

/** Combined info of all user spaces in the instance */
export type InstanceCompressionInfo = {
  __typename?: 'InstanceCompressionInfo';
  /** instance compression info */
  instance_compression_info: Array<SpaceCompressionInfo>;
  /** instance id */
  instance_id: Scalars['String'];
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
  labels?: InputMaybe<Array<InputMaybe<LabelInput>>>;
  rebalancer?: InputMaybe<Scalars['Boolean']>;
  uri: Scalars['String'];
  uuid?: InputMaybe<Scalars['String']>;
  zone?: InputMaybe<Scalars['String']>;
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
  alias?: InputMaybe<Scalars['String']>;
  all_rw?: InputMaybe<Scalars['Boolean']>;
  master?: InputMaybe<Array<Scalars['String']>>;
  roles?: InputMaybe<Array<Scalars['String']>>;
  uuid: Scalars['String'];
  vshard_group?: InputMaybe<Scalars['String']>;
  weight?: InputMaybe<Scalars['Float']>;
};

export type MutationEdit_ServerArgs = {
  labels?: InputMaybe<Array<InputMaybe<LabelInput>>>;
  uri?: InputMaybe<Scalars['String']>;
  uuid: Scalars['String'];
};

export type MutationExpel_ServerArgs = {
  uuid: Scalars['String'];
};

export type MutationJoin_ServerArgs = {
  instance_uuid?: InputMaybe<Scalars['String']>;
  labels?: InputMaybe<Array<InputMaybe<LabelInput>>>;
  replicaset_alias?: InputMaybe<Scalars['String']>;
  replicaset_uuid?: InputMaybe<Scalars['String']>;
  replicaset_weight?: InputMaybe<Scalars['Float']>;
  roles?: InputMaybe<Array<Scalars['String']>>;
  timeout?: InputMaybe<Scalars['Float']>;
  uri: Scalars['String'];
  vshard_group?: InputMaybe<Scalars['String']>;
  zone?: InputMaybe<Scalars['String']>;
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
  /** Checks that the schema can be applied on the cluster */
  check_schema: DdlCheckResult;
  /** Applies updated config on the cluster */
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
  /** Pause failover */
  failover_pause: Scalars['Boolean'];
  /** Promote the instance to the leader of replicaset */
  failover_promote: Scalars['Boolean'];
  /** Resume failover after pausing */
  failover_resume: Scalars['Boolean'];
  /** Remove user */
  remove_user?: Maybe<User>;
  /** Restart replication on servers specified by uuid */
  restart_replication?: Maybe<Scalars['Boolean']>;
  /** Applies DDL schema on cluster */
  schema: DdlSchema;
};

/** Cluster management */
export type MutationApiclusterAdd_UserArgs = {
  email?: InputMaybe<Scalars['String']>;
  fullname?: InputMaybe<Scalars['String']>;
  password: Scalars['String'];
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterAuth_ParamsArgs = {
  cookie_max_age?: InputMaybe<Scalars['Long']>;
  cookie_renew_age?: InputMaybe<Scalars['Long']>;
  enabled?: InputMaybe<Scalars['Boolean']>;
};

/** Cluster management */
export type MutationApiclusterCheck_SchemaArgs = {
  as_yaml: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterConfigArgs = {
  sections?: InputMaybe<Array<InputMaybe<ConfigSectionInput>>>;
};

/** Cluster management */
export type MutationApiclusterConfig_Force_ReapplyArgs = {
  uuids?: InputMaybe<Array<InputMaybe<Scalars['String']>>>;
};

/** Cluster management */
export type MutationApiclusterDisable_ServersArgs = {
  uuids?: InputMaybe<Array<Scalars['String']>>;
};

/** Cluster management */
export type MutationApiclusterEdit_TopologyArgs = {
  replicasets?: InputMaybe<Array<InputMaybe<EditReplicasetInput>>>;
  servers?: InputMaybe<Array<InputMaybe<EditServerInput>>>;
};

/** Cluster management */
export type MutationApiclusterEdit_UserArgs = {
  email?: InputMaybe<Scalars['String']>;
  fullname?: InputMaybe<Scalars['String']>;
  password?: InputMaybe<Scalars['String']>;
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterEdit_Vshard_OptionsArgs = {
  collect_bucket_garbage_interval?: InputMaybe<Scalars['Float']>;
  collect_lua_garbage?: InputMaybe<Scalars['Boolean']>;
  name: Scalars['String'];
  rebalancer_disbalance_threshold?: InputMaybe<Scalars['Float']>;
  rebalancer_max_receiving?: InputMaybe<Scalars['Int']>;
  rebalancer_max_sending?: InputMaybe<Scalars['Int']>;
  rebalancer_mode?: InputMaybe<Scalars['String']>;
  sched_move_quota?: InputMaybe<Scalars['Long']>;
  sched_ref_quota?: InputMaybe<Scalars['Long']>;
  sync_timeout?: InputMaybe<Scalars['Float']>;
};

/** Cluster management */
export type MutationApiclusterFailoverArgs = {
  enabled: Scalars['Boolean'];
};

/** Cluster management */
export type MutationApiclusterFailover_ParamsArgs = {
  autoreturn_delay?: InputMaybe<Scalars['Float']>;
  check_cookie_hash?: InputMaybe<Scalars['Boolean']>;
  etcd2_params?: InputMaybe<FailoverStateProviderCfgInputEtcd2>;
  failover_timeout?: InputMaybe<Scalars['Float']>;
  fencing_enabled?: InputMaybe<Scalars['Boolean']>;
  fencing_pause?: InputMaybe<Scalars['Float']>;
  fencing_timeout?: InputMaybe<Scalars['Float']>;
  leader_autoreturn?: InputMaybe<Scalars['Boolean']>;
  mode?: InputMaybe<Scalars['String']>;
  state_provider?: InputMaybe<Scalars['String']>;
  tarantool_params?: InputMaybe<FailoverStateProviderCfgInputTarantool>;
};

/** Cluster management */
export type MutationApiclusterFailover_PromoteArgs = {
  force_inconsistency?: InputMaybe<Scalars['Boolean']>;
  instance_uuid: Scalars['String'];
  replicaset_uuid: Scalars['String'];
  skip_error_on_change?: InputMaybe<Scalars['Boolean']>;
};

/** Cluster management */
export type MutationApiclusterRemove_UserArgs = {
  username: Scalars['String'];
};

/** Cluster management */
export type MutationApiclusterRestart_ReplicationArgs = {
  uuids?: InputMaybe<Array<Scalars['String']>>;
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
  uuid?: InputMaybe<Scalars['String']>;
};

export type QueryServersArgs = {
  uuid?: InputMaybe<Scalars['String']>;
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
  downstream_lag?: Maybe<Scalars['Float']>;
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
  /** Is the rebalancer enabled for the replica set. */
  rebalancer?: Maybe<Scalars['Boolean']>;
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
  /** Is allowed to elect this instance as leader */
  electable?: Maybe<Scalars['Boolean']>;
  labels?: Maybe<Array<Maybe<Label>>>;
  message: Scalars['String'];
  /** Failover priority within the replica set */
  priority?: Maybe<Scalars['Int']>;
  /** Is rebalancer enabled for this instance */
  rebalancer?: Maybe<Scalars['Boolean']>;
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
  /** VShard version */
  vshard_version?: Maybe<Scalars['String']>;
};

export type ServerInfoGeneral = {
  __typename?: 'ServerInfoGeneral';
  /** The Application version */
  app_version?: Maybe<Scalars['String']>;
  /** Leader idle value in seconds */
  election_leader_idle?: Maybe<Scalars['Float']>;
  /** Instance election mode */
  election_mode: Scalars['String'];
  /** State after Raft leader election */
  election_state?: Maybe<Scalars['String']>;
  /** HTTP host */
  http_host?: Maybe<Scalars['String']>;
  /** HTTP port */
  http_port?: Maybe<Scalars['Int']>;
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
  /** Current read-only state reason */
  ro_reason?: Maybe<Scalars['String']>;
  /** Id of current queue owner */
  synchro_queue_owner: Scalars['Int'];
  /** The number of seconds since the instance started */
  uptime: Scalars['Float'];
  /** The Tarantool version */
  version: Scalars['String'];
  /** A directory where vinyl files or subdirectories will be stored */
  vinyl_dir?: Maybe<Scalars['String']>;
  /** A directory where write-ahead log (.xlog) files are stored */
  wal_dir?: Maybe<Scalars['String']>;
  /** HTTP webui prefix */
  webui_prefix?: Maybe<Scalars['String']>;
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
  /** The server will sleep for `io_collect_interval` seconds between iterations of the event loop */
  io_collect_interval?: Maybe<Scalars['Float']>;
  /** Since if the net_msg_max limit is reached, we will stop processing incoming requests */
  net_msg_max?: Maybe<Scalars['Long']>;
  /** The size of the read-ahead buffer associated with a client connection */
  readahead?: Maybe<Scalars['Long']>;
};

export type ServerInfoReplication = {
  __typename?: 'ServerInfoReplication';
  /**
   * Minimal number of replicas to sync for this instance to switch to the write
   * mode. If set to REPLICATION_CONNECT_QUORUM_ALL, wait for all configured masters.
   */
  replication_connect_quorum?: Maybe<Scalars['Int']>;
  /**
   * Maximal time box.cfg() may wait for connections to all configured replicas to
   * be established. If box.cfg() fails to connect to all replicas within the
   * timeout, it will either leave the instance in the orphan mode (recovery) or
   * fail (bootstrap, reconfiguration).
   */
  replication_connect_timeout?: Maybe<Scalars['Float']>;
  /** Statistics for all instances in the replica set in regard to the current instance */
  replication_info?: Maybe<Array<Maybe<ReplicaStatus>>>;
  /** Allows automatic skip of conflicting rows in replication based on box.cfg configuration option. */
  replication_skip_conflict?: Maybe<Scalars['Boolean']>;
  /** Switch applier from "sync" to "follow" as soon as the replication lag is less than the value of the following variable. */
  replication_sync_lag?: Maybe<Scalars['Float']>;
  /** Max time to wait for appliers to synchronize before entering the orphan mode. */
  replication_sync_timeout?: Maybe<Scalars['Float']>;
  /** How many threads to use for decoding incoming replication stream. */
  replication_threads?: Maybe<Scalars['Float']>;
  /** Wait for the given period of time before trying to reconnect to a master. */
  replication_timeout?: Maybe<Scalars['Float']>;
  /** The vector clock of replication log sequence numbers */
  vclock?: Maybe<Array<Maybe<Scalars['Long']>>>;
};

export type ServerInfoStorage = {
  __typename?: 'ServerInfoStorage';
  /** Allows to select the appropriate allocator for memtx tuples if necessary. */
  memtx_allocator?: Maybe<Scalars['String']>;
  /** Size of the largest allocation unit, in bytes. It can be tuned up if it is necessary to store large tuples. */
  memtx_max_tuple_size?: Maybe<Scalars['Long']>;
  /** How much memory Memtx engine allocates to actually store tuples, in bytes. */
  memtx_memory?: Maybe<Scalars['Long']>;
  /** Size of the smallest allocation unit, in bytes. It can be tuned up if most of the tuples are not so small. */
  memtx_min_tuple_size?: Maybe<Scalars['Long']>;
  /** Deprecated. See "wal_max_size" */
  rows_per_wal?: Maybe<Scalars['Long']>;
  /** Warning in the WAL log if a transaction waits for quota for more than `too_long_threshold` seconds */
  too_long_threshold?: Maybe<Scalars['Float']>;
  /** Bloom filter false positive rate */
  vinyl_bloom_fpr?: Maybe<Scalars['Float']>;
  /** The cache size for the vinyl storage engine */
  vinyl_cache?: Maybe<Scalars['Long']>;
  /** Size of the largest allocation unit, for the vinyl storage engine */
  vinyl_max_tuple_size?: Maybe<Scalars['Long']>;
  /** The maximum number of in-memory bytes that vinyl uses */
  vinyl_memory?: Maybe<Scalars['Long']>;
  /** Page size. Page is a read/write unit for vinyl disk operations */
  vinyl_page_size?: Maybe<Scalars['Long']>;
  /** The default maximum range size for a vinyl index, in bytes */
  vinyl_range_size?: Maybe<Scalars['Long']>;
  /** The maximum number of read threads that vinyl can use for some concurrent operations, such as I/O and compression */
  vinyl_read_threads?: Maybe<Scalars['Int']>;
  /** The maximal number of runs per level in vinyl LSM tree */
  vinyl_run_count_per_level?: Maybe<Scalars['Int']>;
  /** Ratio between the sizes of different levels in the LSM tree */
  vinyl_run_size_ratio?: Maybe<Scalars['Float']>;
  /** Timeout between compactions */
  vinyl_timeout?: Maybe<Scalars['Float']>;
  /** The maximum number of write threads that vinyl can use for some concurrent operations, such as I/O and compression */
  vinyl_write_threads?: Maybe<Scalars['Int']>;
  /** Option to prevent early cleanup of `*.xlog` files which are needed by replicas and lead to `XlogGapError` */
  wal_cleanup_delay?: Maybe<Scalars['Long']>;
  /** Background fiber restart delay to follow xlog changes. */
  wal_dir_rescan_delay?: Maybe<Scalars['Float']>;
  /** The maximal size of a single write-ahead log file */
  wal_max_size?: Maybe<Scalars['Long']>;
  /**
   * Specify fiber-WAL-disk synchronization mode as: "none": write-ahead log is not
   * maintained; "write": fibers wait for their data to be written to the
   * write-ahead log; "fsync": fibers wait for their data, fsync follows each write.
   */
  wal_mode?: Maybe<Scalars['String']>;
  /** Limit the pace at which replica submits new transactions to WAL */
  wal_queue_max_size?: Maybe<Scalars['Long']>;
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
  /** Whether the rebalancer is enabled */
  rebalancer_enabled?: Maybe<Scalars['Boolean']>;
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

/** List of fields compression info */
export type SpaceCompressionInfo = {
  __typename?: 'SpaceCompressionInfo';
  /** list of fields be compressed */
  fields_be_compressed: Array<FieldCompressionInfo>;
  /** space name */
  space_name: Scalars['String'];
};

/** Failover state provider status */
export type StateProviderStatus = {
  __typename?: 'StateProviderStatus';
  /** State provider status */
  status: Scalars['Boolean'];
  /** State provider uri */
  uri: Scalars['String'];
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
  /**
   * The interval between garbage collector actions, in seconds
   * @deprecated Has no effect anymore
   */
  collect_bucket_garbage_interval?: Maybe<Scalars['Float']>;
  /**
   * If set to true, the Lua collectgarbage() function is called periodically
   * @deprecated Has no effect anymore
   */
  collect_lua_garbage?: Maybe<Scalars['Boolean']>;
  /** Group name */
  name: Scalars['String'];
  /** A maximum bucket disbalance threshold, in percent */
  rebalancer_disbalance_threshold: Scalars['Float'];
  /** The maximum number of buckets that can be received in parallel by a single replica set in the storage group */
  rebalancer_max_receiving: Scalars['Int'];
  /** The maximum number of buckets that can be sent in parallel by a single replica set in the storage group */
  rebalancer_max_sending: Scalars['Int'];
  /** Rebalancer mode */
  rebalancer_mode: Scalars['String'];
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
  includeDeprecated?: InputMaybe<Scalars['Boolean']>;
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
  includeDeprecated?: InputMaybe<Scalars['Boolean']>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __TypeEnumValuesArgs = {
  includeDeprecated?: InputMaybe<Scalars['Boolean']>;
};

/**
 * The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.
 *
 * Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByUrl`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
 */
export type __TypeInputFieldsArgs = {
  includeDeprecated?: InputMaybe<Scalars['Boolean']>;
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
  statistics?: {
    __typename?: 'ServerStat';
    quota_used_ratio: string;
    arena_used_ratio: string;
    items_used_ratio: string;
    quotaSize: number;
    arenaUsed: number;
    quotaUsed: number;
    arenaSize: number;
    bucketsCount?: number | null;
  } | null;
};

export type AuthQueryVariables = Exact<{ [key: string]: never }>;

export type AuthQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    authParams: { __typename?: 'UserManagementAPI'; enabled: boolean; username?: string | null };
  } | null;
};

export type TurnAuthMutationVariables = Exact<{
  enabled?: InputMaybe<Scalars['Boolean']>;
}>;

export type TurnAuthMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    authParams: { __typename?: 'UserManagementAPI'; enabled: boolean };
  } | null;
};

export type GetClusterQueryVariables = Exact<{ [key: string]: never }>;

export type GetClusterQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    can_bootstrap_vshard: boolean;
    vshard_bucket_count: number;
    MenuBlacklist?: Array<string> | null;
    clusterSelf?: {
      __typename?: 'ServerShortInfo';
      app_name?: string | null;
      instance_name?: string | null;
      demo_uri?: string | null;
      uri: string;
      uuid?: string | null;
    } | null;
    failover_params: {
      __typename?: 'FailoverAPI';
      failover_timeout: number;
      fencing_enabled: boolean;
      fencing_timeout: number;
      fencing_pause: number;
      leader_autoreturn: boolean;
      autoreturn_delay: number;
      check_cookie_hash: boolean;
      mode: string;
      state_provider?: string | null;
      etcd2_params?: {
        __typename?: 'FailoverStateProviderCfgEtcd2';
        password: string;
        lock_delay: number;
        endpoints: Array<string>;
        username: string;
        prefix: string;
      } | null;
      tarantool_params?: { __typename?: 'FailoverStateProviderCfgTarantool'; uri: string; password: string } | null;
    };
    knownRoles: Array<{
      __typename?: 'Role';
      name: string;
      dependencies?: Array<string> | null;
      implies_storage: boolean;
      implies_router: boolean;
    }>;
    vshard_groups: Array<{
      __typename?: 'VshardGroup';
      name: string;
      bucket_count: number;
      bootstrapped: boolean;
      rebalancer_mode: string;
    }>;
    authParams: {
      __typename?: 'UserManagementAPI';
      enabled: boolean;
      implements_add_user: boolean;
      implements_check_password: boolean;
      implements_list_users: boolean;
      implements_edit_user: boolean;
      implements_remove_user: boolean;
      username?: string | null;
    };
  } | null;
};

export type GetClusterCompressionQueryVariables = Exact<{ [key: string]: never }>;

export type GetClusterCompressionQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    cluster_compression: {
      __typename?: 'ClusterCompressionInfo';
      compression_info: Array<{
        __typename?: 'InstanceCompressionInfo';
        instance_id: string;
        instance_compression_info: Array<{
          __typename?: 'SpaceCompressionInfo';
          space_name: string;
          fields_be_compressed: Array<{
            __typename?: 'FieldCompressionInfo';
            field_name: string;
            compression_percentage: number;
          }>;
        }>;
      }>;
    };
  } | null;
};

export type ServerDetailsFieldsFragment = {
  __typename?: 'Server';
  alias?: string | null;
  status: string;
  message: string;
  uri: string;
  replicaset?: {
    __typename?: 'Replicaset';
    roles?: Array<string> | null;
    active_master: { __typename?: 'Server'; uuid: string };
    master: { __typename?: 'Server'; uuid: string };
  } | null;
  labels?: Array<{ __typename?: 'Label'; name: string; value: string } | null> | null;
  boxinfo?: {
    __typename?: 'ServerInfo';
    cartridge: { __typename?: 'ServerInfoCartridge'; version: string; vshard_version: string | null };
    membership: {
      __typename?: 'ServerInfoMembership';
      status?: string | null;
      incarnation?: number | null;
      PROTOCOL_PERIOD_SECONDS?: number | null;
      ACK_TIMEOUT_SECONDS?: number | null;
      ANTI_ENTROPY_PERIOD_SECONDS?: number | null;
      SUSPECT_TIMEOUT_SECONDS?: number | null;
      NUM_FAILURE_DETECTION_SUBGROUPS?: number | null;
    };
    vshard_router?: Array<{
      __typename?: 'VshardRouter';
      vshard_group?: string | null;
      buckets_unreachable?: number | null;
      buckets_available_ro?: number | null;
      buckets_unknown?: number | null;
      buckets_available_rw?: number | null;
    } | null> | null;
    vshard_storage?: {
      __typename?: 'ServerInfoVshardStorage';
      vshard_group?: string | null;
      buckets_receiving?: number | null;
      buckets_active?: number | null;
      buckets_total?: number | null;
      buckets_garbage?: number | null;
      buckets_pinned?: number | null;
      buckets_sending?: number | null;
      rebalancer_enabled?: boolean | null;
    } | null;
    network: {
      __typename?: 'ServerInfoNetwork';
      io_collect_interval?: number | null;
      net_msg_max?: number | null;
      readahead?: number | null;
    };
    general: {
      __typename?: 'ServerInfoGeneral';
      instance_uuid: string;
      uptime: number;
      version: string;
      ro: boolean;
      http_port?: number | null;
      http_host?: string | null;
      webui_prefix?: string | null;
      app_version?: string | null;
      pid: number;
      replicaset_uuid: string;
      work_dir?: string | null;
      memtx_dir?: string | null;
      vinyl_dir?: string | null;
      wal_dir?: string | null;
      worker_pool_threads?: number | null;
      listen?: string | null;
      election_state?: string | null;
      election_mode: string;
      synchro_queue_owner: number;
      ro_reason?: string | null;
    };
    replication: {
      __typename?: 'ServerInfoReplication';
      replication_connect_quorum?: number | null;
      replication_connect_timeout?: number | null;
      replication_sync_timeout?: number | null;
      replication_skip_conflict?: boolean | null;
      replication_sync_lag?: number | null;
      vclock?: Array<number | null> | null;
      replication_timeout?: number | null;
      replication_info?: Array<{
        __typename?: 'ReplicaStatus';
        downstream_status?: string | null;
        id?: number | null;
        upstream_peer?: string | null;
        upstream_idle?: number | null;
        upstream_message?: string | null;
        lsn?: number | null;
        upstream_lag?: number | null;
        upstream_status?: string | null;
        uuid: string;
        downstream_message?: string | null;
      } | null> | null;
    };
    storage: {
      __typename?: 'ServerInfoStorage';
      wal_max_size?: number | null;
      vinyl_run_count_per_level?: number | null;
      rows_per_wal?: number | null;
      vinyl_cache?: number | null;
      vinyl_range_size?: number | null;
      vinyl_timeout?: number | null;
      memtx_min_tuple_size?: number | null;
      vinyl_bloom_fpr?: number | null;
      vinyl_page_size?: number | null;
      memtx_max_tuple_size?: number | null;
      vinyl_run_size_ratio?: number | null;
      wal_mode?: string | null;
      memtx_memory?: number | null;
      vinyl_memory?: number | null;
      too_long_threshold?: number | null;
      vinyl_max_tuple_size?: number | null;
      vinyl_write_threads?: number | null;
      vinyl_read_threads?: number | null;
      wal_dir_rescan_delay?: number | null;
    };
  } | null;
};

export type InstanceDataQueryVariables = Exact<{
  uuid?: InputMaybe<Scalars['String']>;
}>;

export type InstanceDataQuery = {
  __typename?: 'Query';
  servers?: Array<{
    __typename?: 'Server';
    alias?: string | null;
    status: string;
    message: string;
    uri: string;
    replicaset?: {
      __typename?: 'Replicaset';
      roles?: Array<string> | null;
      active_master: { __typename?: 'Server'; uuid: string };
      master: { __typename?: 'Server'; uuid: string };
    } | null;
    labels?: Array<{ __typename?: 'Label'; name: string; value: string } | null> | null;
    boxinfo?: {
      __typename?: 'ServerInfo';
      cartridge: { __typename?: 'ServerInfoCartridge'; version: string; vshard_version: string | null };
      membership: {
        __typename?: 'ServerInfoMembership';
        status?: string | null;
        incarnation?: number | null;
        PROTOCOL_PERIOD_SECONDS?: number | null;
        ACK_TIMEOUT_SECONDS?: number | null;
        ANTI_ENTROPY_PERIOD_SECONDS?: number | null;
        SUSPECT_TIMEOUT_SECONDS?: number | null;
        NUM_FAILURE_DETECTION_SUBGROUPS?: number | null;
      };
      vshard_router?: Array<{
        __typename?: 'VshardRouter';
        vshard_group?: string | null;
        buckets_unreachable?: number | null;
        buckets_available_ro?: number | null;
        buckets_unknown?: number | null;
        buckets_available_rw?: number | null;
      } | null> | null;
      vshard_storage?: {
        __typename?: 'ServerInfoVshardStorage';
        vshard_group?: string | null;
        buckets_receiving?: number | null;
        buckets_active?: number | null;
        buckets_total?: number | null;
        buckets_garbage?: number | null;
        buckets_pinned?: number | null;
        buckets_sending?: number | null;
        rebalancer_enabled?: boolean | null;
      } | null;
      network: {
        __typename?: 'ServerInfoNetwork';
        io_collect_interval?: number | null;
        net_msg_max?: number | null;
        readahead?: number | null;
      };
      general: {
        __typename?: 'ServerInfoGeneral';
        instance_uuid: string;
        uptime: number;
        version: string;
        ro: boolean;
        http_port?: number | null;
        http_host?: string | null;
        webui_prefix?: string | null;
        app_version?: string | null;
        pid: number;
        replicaset_uuid: string;
        work_dir?: string | null;
        memtx_dir?: string | null;
        vinyl_dir?: string | null;
        wal_dir?: string | null;
        worker_pool_threads?: number | null;
        listen?: string | null;
        election_state?: string | null;
        election_mode: string;
        synchro_queue_owner: number;
        ro_reason?: string | null;
      };
      replication: {
        __typename?: 'ServerInfoReplication';
        replication_connect_quorum?: number | null;
        replication_connect_timeout?: number | null;
        replication_sync_timeout?: number | null;
        replication_skip_conflict?: boolean | null;
        replication_sync_lag?: number | null;
        vclock?: Array<number | null> | null;
        replication_timeout?: number | null;
        replication_info?: Array<{
          __typename?: 'ReplicaStatus';
          downstream_status?: string | null;
          id?: number | null;
          upstream_peer?: string | null;
          upstream_idle?: number | null;
          upstream_message?: string | null;
          lsn?: number | null;
          upstream_lag?: number | null;
          upstream_status?: string | null;
          uuid: string;
          downstream_message?: string | null;
        } | null> | null;
      };
      storage: {
        __typename?: 'ServerInfoStorage';
        wal_max_size?: number | null;
        vinyl_run_count_per_level?: number | null;
        rows_per_wal?: number | null;
        vinyl_cache?: number | null;
        vinyl_range_size?: number | null;
        vinyl_timeout?: number | null;
        memtx_min_tuple_size?: number | null;
        vinyl_bloom_fpr?: number | null;
        vinyl_page_size?: number | null;
        memtx_max_tuple_size?: number | null;
        vinyl_run_size_ratio?: number | null;
        wal_mode?: string | null;
        memtx_memory?: number | null;
        vinyl_memory?: number | null;
        too_long_threshold?: number | null;
        vinyl_max_tuple_size?: number | null;
        vinyl_write_threads?: number | null;
        vinyl_read_threads?: number | null;
        wal_dir_rescan_delay?: number | null;
      };
    } | null;
  } | null> | null;
  descriptionCartridge?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionMembership?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionVshardRouter?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionVshardStorage?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionGeneral?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionNetwork?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionReplication?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
  descriptionStorage?: {
    __typename?: '__Type';
    fields?: Array<{ __typename?: '__Field'; name: string; description?: string | null }> | null;
  } | null;
};

export type BoxInfoQueryVariables = Exact<{
  uuid?: InputMaybe<Scalars['String']>;
}>;

export type BoxInfoQuery = {
  __typename?: 'Query';
  servers?: Array<{
    __typename?: 'Server';
    alias?: string | null;
    status: string;
    message: string;
    uri: string;
    replicaset?: {
      __typename?: 'Replicaset';
      roles?: Array<string> | null;
      active_master: { __typename?: 'Server'; uuid: string };
      master: { __typename?: 'Server'; uuid: string };
    } | null;
    labels?: Array<{ __typename?: 'Label'; name: string; value: string } | null> | null;
    boxinfo?: {
      __typename?: 'ServerInfo';
      cartridge: { __typename?: 'ServerInfoCartridge'; version: string; vshard_version: string | null };
      membership: {
        __typename?: 'ServerInfoMembership';
        status?: string | null;
        incarnation?: number | null;
        PROTOCOL_PERIOD_SECONDS?: number | null;
        ACK_TIMEOUT_SECONDS?: number | null;
        ANTI_ENTROPY_PERIOD_SECONDS?: number | null;
        SUSPECT_TIMEOUT_SECONDS?: number | null;
        NUM_FAILURE_DETECTION_SUBGROUPS?: number | null;
      };
      vshard_router?: Array<{
        __typename?: 'VshardRouter';
        vshard_group?: string | null;
        buckets_unreachable?: number | null;
        buckets_available_ro?: number | null;
        buckets_unknown?: number | null;
        buckets_available_rw?: number | null;
      } | null> | null;
      vshard_storage?: {
        __typename?: 'ServerInfoVshardStorage';
        vshard_group?: string | null;
        buckets_receiving?: number | null;
        buckets_active?: number | null;
        buckets_total?: number | null;
        buckets_garbage?: number | null;
        buckets_pinned?: number | null;
        buckets_sending?: number | null;
        rebalancer_enabled?: boolean | null;
      } | null;
      network: {
        __typename?: 'ServerInfoNetwork';
        io_collect_interval?: number | null;
        net_msg_max?: number | null;
        readahead?: number | null;
      };
      general: {
        __typename?: 'ServerInfoGeneral';
        instance_uuid: string;
        uptime: number;
        version: string;
        ro: boolean;
        http_port?: number | null;
        http_host?: string | null;
        webui_prefix?: string | null;
        app_version?: string | null;
        pid: number;
        replicaset_uuid: string;
        work_dir?: string | null;
        memtx_dir?: string | null;
        vinyl_dir?: string | null;
        wal_dir?: string | null;
        worker_pool_threads?: number | null;
        listen?: string | null;
        election_state?: string | null;
        election_mode: string;
        synchro_queue_owner: number;
        ro_reason?: string | null;
      };
      replication: {
        __typename?: 'ServerInfoReplication';
        replication_connect_quorum?: number | null;
        replication_connect_timeout?: number | null;
        replication_sync_timeout?: number | null;
        replication_skip_conflict?: boolean | null;
        replication_sync_lag?: number | null;
        vclock?: Array<number | null> | null;
        replication_timeout?: number | null;
        replication_info?: Array<{
          __typename?: 'ReplicaStatus';
          downstream_status?: string | null;
          id?: number | null;
          upstream_peer?: string | null;
          upstream_idle?: number | null;
          upstream_message?: string | null;
          lsn?: number | null;
          upstream_lag?: number | null;
          upstream_status?: string | null;
          uuid: string;
          downstream_message?: string | null;
        } | null> | null;
      };
      storage: {
        __typename?: 'ServerInfoStorage';
        wal_max_size?: number | null;
        vinyl_run_count_per_level?: number | null;
        rows_per_wal?: number | null;
        vinyl_cache?: number | null;
        vinyl_range_size?: number | null;
        vinyl_timeout?: number | null;
        memtx_min_tuple_size?: number | null;
        vinyl_bloom_fpr?: number | null;
        vinyl_page_size?: number | null;
        memtx_max_tuple_size?: number | null;
        vinyl_run_size_ratio?: number | null;
        wal_mode?: string | null;
        memtx_memory?: number | null;
        vinyl_memory?: number | null;
        too_long_threshold?: number | null;
        vinyl_max_tuple_size?: number | null;
        vinyl_write_threads?: number | null;
        vinyl_read_threads?: number | null;
        wal_dir_rescan_delay?: number | null;
      };
    } | null;
  } | null> | null;
};

export type ServerListQueryVariables = Exact<{
  withStats: Scalars['Boolean'];
}>;

export type ServerListQuery = {
  __typename?: 'Query';
  failover?: { __typename?: 'Apicluster'; failover_params: { __typename?: 'FailoverAPI'; mode: string } } | null;
  serverList?: Array<{
    __typename?: 'Server';
    uuid: string;
    alias?: string | null;
    disabled?: boolean | null;
    electable?: boolean | null;
    uri: string;
    zone?: string | null;
    status: string;
    message: string;
    rebalancer?: boolean | null;
    labels?: Array<{ __typename?: 'Label'; name: string; value: string } | null> | null;
    boxinfo?: { __typename?: 'ServerInfo'; general: { __typename?: 'ServerInfoGeneral'; ro: boolean } } | null;
    replicaset?: { __typename?: 'Replicaset'; uuid: string } | null;
  } | null> | null;
  replicasetList?: Array<{
    __typename?: 'Replicaset';
    alias: string;
    all_rw: boolean;
    uuid: string;
    status: string;
    roles?: Array<string> | null;
    vshard_group?: string | null;
    rebalancer?: boolean | null;
    weight?: number | null;
    master: { __typename?: 'Server'; uuid: string };
    active_master: { __typename?: 'Server'; uuid: string };
    servers: Array<{
      __typename?: 'Server';
      uuid: string;
      alias?: string | null;
      disabled?: boolean | null;
      electable?: boolean | null;
      uri: string;
      priority?: number | null;
      status: string;
      rebalancer?: boolean | null;
      message: string;
      labels?: Array<{ __typename?: 'Label'; name: string; value: string } | null> | null;
      boxinfo?: {
        __typename?: 'ServerInfo';
        general: { __typename?: 'ServerInfoGeneral'; ro: boolean };
        vshard_storage?: { __typename?: 'ServerInfoVshardStorage'; rebalancer_enabled?: boolean | null } | null;
      } | null;
      replicaset?: { __typename?: 'Replicaset'; uuid: string } | null;
    }>;
  } | null> | null;
  serverStat?: Array<{
    __typename?: 'Server';
    uuid: string;
    uri: string;
    statistics?: {
      __typename?: 'ServerStat';
      quota_used_ratio: string;
      arena_used_ratio: string;
      items_used_ratio: string;
      quotaSize: number;
      arenaUsed: number;
      quotaUsed: number;
      arenaSize: number;
      bucketsCount?: number | null;
    } | null;
  } | null> | null;
  cluster?: {
    __typename?: 'Apicluster';
    known_roles: Array<{
      __typename?: 'Role';
      name: string;
      dependencies?: Array<string> | null;
      implies_storage: boolean;
      implies_router: boolean;
    }>;
    suggestions?: {
      __typename?: 'Suggestions';
      disable_servers?: Array<{ __typename?: 'DisableServerSuggestion'; uuid: string }> | null;
      restart_replication?: Array<{ __typename?: 'RestartReplicationSuggestion'; uuid: string }> | null;
      force_apply?: Array<{
        __typename?: 'ForceApplySuggestion';
        config_mismatch: boolean;
        config_locked: boolean;
        uuid: string;
        operation_error: boolean;
      }> | null;
      refine_uri?: Array<{ __typename?: 'RefineUriSuggestion'; uuid: string; uri_old: string; uri_new: string }> | null;
    } | null;
    issues?: Array<{
      __typename?: 'Issue';
      level: string;
      replicaset_uuid?: string | null;
      instance_uuid?: string | null;
      message: string;
      topic: string;
    }> | null;
  } | null;
};

export type ServerStatQueryVariables = Exact<{ [key: string]: never }>;

export type ServerStatQuery = {
  __typename?: 'Query';
  serverStat?: Array<{
    __typename?: 'Server';
    uuid: string;
    uri: string;
    statistics?: {
      __typename?: 'ServerStat';
      quota_used_ratio: string;
      arena_used_ratio: string;
      items_used_ratio: string;
      quotaSize: number;
      arenaUsed: number;
      quotaUsed: number;
      arenaSize: number;
      bucketsCount?: number | null;
    } | null;
  } | null> | null;
};

export type BootstrapMutationVariables = Exact<{ [key: string]: never }>;

export type BootstrapMutation = { __typename?: 'Mutation'; bootstrapVshardResponse?: boolean | null };

export type ProbeMutationVariables = Exact<{
  uri: Scalars['String'];
}>;

export type ProbeMutation = { __typename?: 'Mutation'; probeServerResponse?: boolean | null };

export type EditTopologyMutationVariables = Exact<{
  replicasets?: InputMaybe<Array<EditReplicasetInput> | EditReplicasetInput>;
  servers?: InputMaybe<Array<EditServerInput> | EditServerInput>;
}>;

export type EditTopologyMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    edit_topology?: {
      __typename?: 'EditTopologyResult';
      servers: Array<{ __typename?: 'Server'; uuid: string } | null>;
    } | null;
  } | null;
};

export type ChangeRebalancerModeMutationVariables = Exact<{
  name: Scalars['String'];
  rebalancer_mode: Scalars['String'];
}>;

export type ChangeRebalancerModeMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    edit_vshard_options: { __typename?: 'VshardGroup'; rebalancer_mode: string };
  } | null;
};

export type ChangeFailoverMutationVariables = Exact<{
  failover_timeout?: InputMaybe<Scalars['Float']>;
  fencing_enabled?: InputMaybe<Scalars['Boolean']>;
  fencing_timeout?: InputMaybe<Scalars['Float']>;
  fencing_pause?: InputMaybe<Scalars['Float']>;
  leader_autoreturn?: InputMaybe<Scalars['Boolean']>;
  autoreturn_delay?: InputMaybe<Scalars['Float']>;
  check_cookie_hash?: InputMaybe<Scalars['Boolean']>;
  mode: Scalars['String'];
  state_provider?: InputMaybe<Scalars['String']>;
  etcd2_params?: InputMaybe<FailoverStateProviderCfgInputEtcd2>;
  tarantool_params?: InputMaybe<FailoverStateProviderCfgInputTarantool>;
}>;

export type ChangeFailoverMutation = {
  __typename?: 'Mutation';
  cluster?: { __typename?: 'MutationApicluster'; failover_params: { __typename?: 'FailoverAPI'; mode: string } } | null;
};

export type PromoteFailoverLeaderMutationVariables = Exact<{
  replicaset_uuid: Scalars['String'];
  instance_uuid: Scalars['String'];
  force_inconsistency?: InputMaybe<Scalars['Boolean']>;
}>;

export type PromoteFailoverLeaderMutation = {
  __typename?: 'Mutation';
  cluster?: { __typename?: 'MutationApicluster'; failover_promote: boolean } | null;
};

export type FetchUsersQueryVariables = Exact<{ [key: string]: never }>;

export type FetchUsersQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    users?: Array<{ __typename?: 'User'; username: string; fullname?: string | null; email?: string | null }> | null;
  } | null;
};

export type AddUserMutationVariables = Exact<{
  username: Scalars['String'];
  password: Scalars['String'];
  email: Scalars['String'];
  fullname: Scalars['String'];
}>;

export type AddUserMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    add_user?: { __typename?: 'User'; username: string; email?: string | null; fullname?: string | null } | null;
  } | null;
};

export type EditUserMutationVariables = Exact<{
  username: Scalars['String'];
  password?: InputMaybe<Scalars['String']>;
  email?: InputMaybe<Scalars['String']>;
  fullname?: InputMaybe<Scalars['String']>;
}>;

export type EditUserMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    edit_user?: { __typename?: 'User'; username: string; email?: string | null; fullname?: string | null } | null;
  } | null;
};

export type RemoveUserMutationVariables = Exact<{
  username: Scalars['String'];
}>;

export type RemoveUserMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    remove_user?: { __typename?: 'User'; username: string; email?: string | null; fullname?: string | null } | null;
  } | null;
};

export type Set_FilesMutationVariables = Exact<{
  files?: InputMaybe<Array<ConfigSectionInput> | ConfigSectionInput>;
}>;

export type Set_FilesMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    config: Array<{ __typename?: 'ConfigSection'; filename: string; content: string } | null>;
  } | null;
};

export type Disable_ServersMutationVariables = Exact<{
  uuids?: InputMaybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Disable_ServersMutation = {
  __typename?: 'Mutation';
  cluster?: {
    __typename?: 'MutationApicluster';
    disable_servers?: Array<{ __typename?: 'Server'; uuid: string; disabled?: boolean | null } | null> | null;
  } | null;
};

export type Restart_ReplicationMutationVariables = Exact<{
  uuids?: InputMaybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Restart_ReplicationMutation = {
  __typename?: 'Mutation';
  cluster?: { __typename?: 'MutationApicluster'; restart_replication?: boolean | null } | null;
};

export type Config_Force_ReapplyMutationVariables = Exact<{
  uuids?: InputMaybe<Array<Scalars['String']> | Scalars['String']>;
}>;

export type Config_Force_ReapplyMutation = {
  __typename?: 'Mutation';
  cluster?: { __typename?: 'MutationApicluster'; config_force_reapply: boolean } | null;
};

export type ConfigFilesQueryVariables = Exact<{ [key: string]: never }>;

export type ConfigFilesQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    config: Array<{ __typename?: 'ConfigSection'; content: string; path: string } | null>;
  } | null;
};

export type GetFailoverParamsQueryVariables = Exact<{ [key: string]: never }>;

export type GetFailoverParamsQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    failover_params: {
      __typename?: 'FailoverAPI';
      failover_timeout: number;
      fencing_enabled: boolean;
      fencing_timeout: number;
      fencing_pause: number;
      leader_autoreturn: boolean;
      autoreturn_delay: number;
      check_cookie_hash: boolean;
      mode: string;
      state_provider?: string | null;
      etcd2_params?: {
        __typename?: 'FailoverStateProviderCfgEtcd2';
        password: string;
        lock_delay: number;
        endpoints: Array<string>;
        username: string;
        prefix: string;
      } | null;
      tarantool_params?: { __typename?: 'FailoverStateProviderCfgTarantool'; uri: string; password: string } | null;
    };
  } | null;
};

export type ValidateConfigQueryVariables = Exact<{
  sections?: InputMaybe<Array<ConfigSectionInput> | ConfigSectionInput>;
}>;

export type ValidateConfigQuery = {
  __typename?: 'Query';
  cluster?: {
    __typename?: 'Apicluster';
    validate_config: { __typename?: 'ValidateConfigResult'; error?: string | null };
  } | null;
};
