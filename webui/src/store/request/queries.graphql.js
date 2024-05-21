// @flow

// eslint-disable-next-line import/no-named-as-default
import gql from 'graphql-tag';

export const serverStatFields = gql`
  fragment serverStatFields on Server {
    uuid
    uri
    statistics {
      quotaSize: quota_size
      arenaUsed: arena_used
      quotaUsed: quota_used
      arenaSize: arena_size
      bucketsCount: vshard_buckets_count
      quota_used_ratio
      arena_used_ratio
      items_used_ratio
    }
  }
`;

export const authQuery = gql`
  query Auth {
    cluster {
      authParams: auth_params {
        enabled
        username
      }
    }
  }
`;

export const turnAuthMutation = gql`
  mutation turnAuth($enabled: Boolean) {
    cluster {
      authParams: auth_params(enabled: $enabled) {
        enabled
      }
    }
  }
`;

export const getClusterQuery = gql`
  query getCluster {
    cluster {
      clusterSelf: self {
        app_name
        instance_name
        uri: uri
        uuid: uuid
        demo_uri
      }
      failover_params {
        failover_timeout
        fencing_enabled
        fencing_timeout
        fencing_pause
        leader_autoreturn
        autoreturn_delay
        check_cookie_hash
        etcd2_params {
          password
          lock_delay
          endpoints
          username
          prefix
        }
        tarantool_params {
          uri
          password
        }
        mode
        state_provider
      }
      knownRoles: known_roles {
        name
        dependencies
        implies_storage
        implies_router
      }
      can_bootstrap_vshard
      vshard_bucket_count
      vshard_groups {
        name
        bucket_count
        bootstrapped
        rebalancer_mode
      }
      authParams: auth_params {
        enabled
        implements_add_user
        implements_check_password
        implements_list_users
        implements_edit_user
        implements_remove_user
        username
      }
      MenuBlacklist: webui_blacklist
    }
  }
`;

export const getClusterCompressionQuery = gql`
  query getClusterCompression {
    cluster {
      cluster_compression {
        compression_info {
          instance_id
          instance_compression_info {
            space_name
            fields_be_compressed {
              field_name
              compression_percentage
            }
          }
        }
      }
    }
  }
`;

export const serverDetailsFields = gql`
  fragment serverDetailsFields on Server {
    alias
    status
    message
    uri
    replicaset {
      roles
      active_master {
        uuid
      }
      master {
        uuid
      }
    }
    labels {
      name
      value
    }
    boxinfo {
      cartridge {
        version
        vshard_version
        ddl_version
      }
      membership {
        status
        incarnation
        PROTOCOL_PERIOD_SECONDS
        ACK_TIMEOUT_SECONDS
        ANTI_ENTROPY_PERIOD_SECONDS
        SUSPECT_TIMEOUT_SECONDS
        NUM_FAILURE_DETECTION_SUBGROUPS
      }
      vshard_router {
        vshard_group
        buckets_unreachable
        buckets_available_ro
        buckets_unknown
        buckets_available_rw
      }
      vshard_storage {
        vshard_group
        buckets_receiving
        buckets_active
        buckets_total
        buckets_garbage
        buckets_pinned
        buckets_sending
        rebalancer_enabled
      }
      network {
        io_collect_interval
        net_msg_max
        readahead
      }
      general {
        instance_uuid
        uptime
        version
        ro
        http_port
        http_host
        webui_prefix
        app_version
        pid
        replicaset_uuid
        work_dir
        memtx_dir
        vinyl_dir
        wal_dir
        worker_pool_threads
        listen
        election_state
        election_mode
        synchro_queue_owner
        ro_reason
      }
      replication {
        replication_connect_quorum
        replication_connect_timeout
        replication_sync_timeout
        replication_skip_conflict
        replication_sync_lag
        replication_info {
          downstream_status
          id
          upstream_peer
          upstream_idle
          upstream_message
          lsn
          upstream_lag
          upstream_status
          uuid
          downstream_message
        }
        vclock
        replication_timeout
      }
      storage {
        wal_max_size
        vinyl_run_count_per_level
        rows_per_wal
        vinyl_cache
        vinyl_range_size
        vinyl_timeout
        memtx_min_tuple_size
        vinyl_bloom_fpr
        vinyl_page_size
        memtx_max_tuple_size
        vinyl_run_size_ratio
        wal_mode
        memtx_memory
        vinyl_memory
        too_long_threshold
        vinyl_max_tuple_size
        vinyl_write_threads
        vinyl_read_threads
        wal_dir_rescan_delay
      }
    }
  }
`;

export const firstServerDetailsQuery = gql`
  query instanceData($uuid: String) {
    servers(uuid: $uuid) {
      ...serverDetailsFields
    }

    descriptionCartridge: __type(name: "ServerInfoCartridge") {
      fields {
        name
        description
      }
    }
    descriptionMembership: __type(name: "ServerInfoMembership") {
      fields {
        name
        description
      }
    }
    descriptionVshardRouter: __type(name: "VshardRouter") {
      fields {
        name
        description
      }
    }
    descriptionVshardStorage: __type(name: "ServerInfoVshardStorage") {
      fields {
        name
        description
      }
    }
    descriptionGeneral: __type(name: "ServerInfoGeneral") {
      fields {
        name
        description
      }
    }
    descriptionNetwork: __type(name: "ServerInfoNetwork") {
      fields {
        name
        description
      }
    }
    descriptionReplication: __type(name: "ServerInfoReplication") {
      fields {
        name
        description
      }
    }
    descriptionStorage: __type(name: "ServerInfoStorage") {
      fields {
        name
        description
      }
    }
  }
  ${serverDetailsFields}
`;

export const nextServerDetailsQuery = gql`
  query boxInfo($uuid: String) {
    servers(uuid: $uuid) {
      ...serverDetailsFields
    }
  }
  ${serverDetailsFields}
`;

export const listQuery = gql`
  query serverList($withStats: Boolean!) {
    failover: cluster {
      failover_params {
        mode
      }
    }
    serverList: servers {
      uuid
      alias
      disabled
      electable
      uri
      zone
      status
      message
      rebalancer
      labels {
        name
        value
      }
      boxinfo {
        general {
          ro
        }
      }
      replicaset {
        uuid
      }
    }
    replicasetList: replicasets {
      alias
      all_rw
      uuid
      status
      roles
      vshard_group
      rebalancer
      master {
        uuid
      }
      active_master {
        uuid
      }
      weight
      servers {
        uuid
        alias
        disabled
        electable
        uri
        priority
        status
        rebalancer
        labels {
          name
          value
        }
        boxinfo {
          general {
            ro
          }
          vshard_storage {
            rebalancer_enabled
          }
        }
        message
        replicaset {
          uuid
        }
      }
    }
    serverStat: servers @include(if: $withStats) {
      ...serverStatFields
    }
    cluster @include(if: $withStats) {
      known_roles {
        name
        dependencies
        implies_storage
        implies_router
      }
      suggestions {
        disable_servers {
          uuid
        }
        restart_replication {
          uuid
        }
        force_apply {
          config_mismatch
          config_locked
          uuid
          operation_error
        }
        refine_uri {
          uuid
          uri_old
          uri_new
        }
      }
      issues {
        level
        replicaset_uuid
        instance_uuid
        message
        topic
      }
    }
  }
  ${serverStatFields}
`;

export const serverStatQuery = gql`
  query serverStat {
    serverStat: servers {
      ...serverStatFields
    }
  }
  ${serverStatFields}
`;

export const bootstrapMutation = gql`
  mutation bootstrap {
    bootstrapVshardResponse: bootstrap_vshard
  }
`;

export const probeMutation = gql`
  mutation probe($uri: String!) {
    probeServerResponse: probe_server(uri: $uri)
  }
`;

export const editTopologyMutation = gql`
  mutation editTopology($replicasets: [EditReplicasetInput!], $servers: [EditServerInput!]) {
    cluster {
      edit_topology(replicasets: $replicasets, servers: $servers) {
        servers {
          uuid
        }
      }
    }
  }
`;

export const changeRebalancerModeMutation = gql`
  mutation changeRebalancerMode($name: String!, $rebalancer_mode: String!) {
    cluster {
      edit_vshard_options(name: $name, rebalancer_mode: $rebalancer_mode) {
        rebalancer_mode
      }
    }
  }
`;

export const changeFailoverMutation = gql`
  mutation changeFailover(
    $failover_timeout: Float
    $fencing_enabled: Boolean
    $fencing_timeout: Float
    $fencing_pause: Float
    $leader_autoreturn: Boolean
    $autoreturn_delay: Float
    $check_cookie_hash: Boolean
    $mode: String!
    $state_provider: String
    $etcd2_params: FailoverStateProviderCfgInputEtcd2
    $tarantool_params: FailoverStateProviderCfgInputTarantool
  ) {
    cluster {
      failover_params(
        failover_timeout: $failover_timeout
        fencing_enabled: $fencing_enabled
        fencing_timeout: $fencing_timeout
        fencing_pause: $fencing_pause
        leader_autoreturn: $leader_autoreturn
        autoreturn_delay: $autoreturn_delay
        check_cookie_hash: $check_cookie_hash
        mode: $mode
        state_provider: $state_provider
        etcd2_params: $etcd2_params
        tarantool_params: $tarantool_params
      ) {
        mode
      }
    }
  }
`;

export const promoteFailoverLeaderMutation = gql`
  mutation promoteFailoverLeader($replicaset_uuid: String!, $instance_uuid: String!, $force_inconsistency: Boolean) {
    cluster {
      failover_promote(
        replicaset_uuid: $replicaset_uuid
        instance_uuid: $instance_uuid
        force_inconsistency: $force_inconsistency
      )
    }
  }
`;

export const fetchUsersQuery = gql`
  query fetchUsers {
    cluster {
      users {
        username
        fullname
        email
      }
    }
  }
`;

export const addUserMutation = gql`
  mutation addUser($username: String!, $password: String!, $email: String!, $fullname: String!) {
    cluster {
      add_user(username: $username, password: $password, email: $email, fullname: $fullname) {
        username
        email
        fullname
      }
    }
  }
`;

export const editUserMutation = gql`
  mutation editUser($username: String!, $password: String, $email: String, $fullname: String) {
    cluster {
      edit_user(username: $username, password: $password, email: $email, fullname: $fullname) {
        username
        email
        fullname
      }
    }
  }
`;

export const removeUserMutation = gql`
  mutation removeUser($username: String!) {
    cluster {
      remove_user(username: $username) {
        username
        email
        fullname
      }
    }
  }
`;

export const setFilesMutation = gql`
  mutation set_files($files: [ConfigSectionInput!]) {
    cluster {
      config(sections: $files) {
        filename
        content
      }
    }
  }
`;

export const disableServersMutation = gql`
  mutation disable_servers($uuids: [String!]) {
    cluster {
      disable_servers(uuids: $uuids) {
        uuid
        disabled
      }
    }
  }
`;

export const restartReplicationMutation = gql`
  mutation restart_replication($uuids: [String!]) {
    cluster {
      restart_replication(uuids: $uuids)
    }
  }
`;

export const configForceReapplyMutation = gql`
  mutation config_force_reapply($uuids: [String!]) {
    cluster {
      config_force_reapply(uuids: $uuids)
    }
  }
`;

export const getFilesQuery = gql`
  query configFiles {
    cluster {
      config {
        path: filename
        content
      }
    }
  }
`;

export const getFailoverParams = gql`
  query getFailoverParams {
    cluster {
      failover_params {
        failover_timeout
        fencing_enabled
        fencing_timeout
        fencing_pause
        leader_autoreturn
        autoreturn_delay
        check_cookie_hash
        etcd2_params {
          password
          lock_delay
          endpoints
          username
          prefix
        }
        tarantool_params {
          uri
          password
        }
        mode
        state_provider
      }
    }
  }
`;

export const getStateProviderStatus = gql`
  query getStateProviderStatus {
    cluster {
      failover_state_provider_status {
        uri
        status
      }
    }
  }
`;

export const validateFilesQuery = gql`
  query validateConfig($sections: [ConfigSectionInput!]) {
    cluster {
      validate_config(sections: $sections) {
        error
      }
    }
  }
`;
