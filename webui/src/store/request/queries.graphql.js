// @flow

import gql from 'graphql-tag';

export const serverStatFields = gql`
  fragment serverStatFields on Server {
    uuid
    uri
    statistics {
      quotaSize: quota_size
      arenaUsed: arena_used
      bucketsCount: vshard_buckets_count
      quota_used_ratio
      arena_used_ratio
      items_used_ratio
    }
  }
`;

export const authQuery =  gql`
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
  mutation turnAuth ($enabled: Boolean) {
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

export const boxInfoQuery = gql`
  query boxInfo ($uuid: String){ 
    servers(uuid: $uuid) {
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
  }
`;

export const instanceDataQuery = gql`
  query instanceData($uuid: String){
    servers(uuid: $uuid) {
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
    
    descriptionCartridge: __type(name: "ServerInfoCartridge") {
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
`;

export const listQuery = gql`
query serverList ($withStats: Boolean!) {
  serverList: servers {
    uuid
    alias
    disabled
    uri
    zone
    status
    message
    boxinfo {
      general { ro }
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
      uri
      priority
      status
      boxinfo {
        general { ro }
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
    suggestions {
      disable_servers {
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
  serverStat: servers { ...serverStatFields }
}
${serverStatFields}
`;

export const bootstrapMutation = gql`
mutation bootstrap {
  bootstrapVshardResponse: bootstrap_vshard
}`;

export const probeMutation = gql`
mutation probe (
  $uri: String!
) {
  probeServerResponse: probe_server(
    uri: $uri
  )
}`;

export const editTopologyMutation = gql`
mutation editTopology (
  $replicasets: [EditReplicasetInput!]
  $servers: [EditServerInput!]
) {
  cluster{edit_topology(
    replicasets: $replicasets
    servers: $servers
  ) {
    servers {
      uuid
    }
  }}
}
`;

export const changeFailoverMutation = gql`
mutation changeFailover (
  $failover_timeout: Float,
  $fencing_enabled: Boolean,
  $fencing_timeout: Float,
  $fencing_pause: Float,
  $mode: String!,
  $state_provider: String,
  $etcd2_params: FailoverStateProviderCfgInputEtcd2,
  $tarantool_params: FailoverStateProviderCfgInputTarantool
) {
  cluster {
    failover_params (
      failover_timeout: $failover_timeout,
      fencing_enabled: $fencing_enabled,
      fencing_timeout: $fencing_timeout,
      fencing_pause: $fencing_pause,
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
mutation promoteFailoverLeader (
  $replicaset_uuid: String!,
  $instance_uuid: String!,
  $force_inconsistency: Boolean
) {
  cluster {
  	failover_promote(
      replicaset_uuid: $replicaset_uuid,
      instance_uuid: $instance_uuid,
      force_inconsistency: $force_inconsistency
    )
  }
}
`

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
mutation addUser(
  $username: String!,
  $password: String!,
  $email: String!,
  $fullname: String!
) {
      cluster {
        add_user(
          username: $username
          password: $password
          email: $email
          fullname: $fullname
        ) {
          username
          email
          fullname
        }
      }
    }
`;

export const editUserMutation = gql`
mutation editUser ($username: String!, $password: String, $email: String, $fullname: String) {
      cluster {
        edit_user(
          username: $username
          password: $password
          email: $email
          fullname: $fullname
        ) {
          username
          email
          fullname
        }
      }
    }
`;

export const removeUserMutation = gql`
  mutation removeUser ($username: String!) {
      cluster {
        remove_user(username: $username) {
          username
          email
          fullname
        }
      }
    }
`;

export const getSchemaQuery = gql`
  query get_schema {
    cluster {
      schema {
        as_yaml
      }
    }
  }
`;

export const setSchemaMutation = gql`
  mutation set_schema($yaml: String!) {
    cluster {
      schema(as_yaml: $yaml) {
        as_yaml
      }
    }
  }
`;


export const checkSchemaMutation = gql`
  mutation check_schema($yaml: String!) {
    cluster {
      check_schema(as_yaml: $yaml) {
        error
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

export const configForceReapplyMutation = gql`
  mutation config_force_reapply ($uuids: [String!]) {
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
