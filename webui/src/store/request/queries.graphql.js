// @flow

import gql from 'graphql-tag'

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
        uri: uri
        uuid: uuid
      }
      failover
      knownRoles: known_roles {
        name
        dependencies
      }
      can_bootstrap_vshard
      vshard_bucket_count
      authParams: auth_params {
        enabled
        implements_add_user
        implements_check_password
        implements_list_users
        implements_edit_user
        implements_remove_user
        username
      }
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

export const pageQuery = gql`
query page {
  serverList: servers {
    uuid
    alias
    uri
    status
    message
    replicaset {
      uuid
    }
  }
  replicasetList: replicasets {
    uuid
    status
    roles
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
      uri
      status
      message
      replicaset {
        uuid
      }
      labels {
        name
        value
      }
    }
  }
  serverStat: servers {
    uuid
    statistics {
      quotaSize: quota_size
      arenaUsed: arena_used
    }
  }
}
`;

export const listQuery = gql`
query serverList {
  serverList: servers {
    uuid
    alias
    uri
    status
    message
    replicaset {
      uuid
    }
  }
  replicasetList: replicasets {
    uuid
    status
    roles
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
      uri
      status
      message
      replicaset {
        uuid
      }
      labels {
        name
        value
      }
    }
  }
  serverStat: servers {
    uuid
    uri
    statistics {
      quotaSize: quota_size
      arenaUsed: arena_used
    }
  }
}
`;

export const listQueryWithoutStat = gql`
query serverListWithoutStat {
  serverList: servers {
    uuid
    alias
    uri
    status
    message
    replicaset {
      uuid
    }
  }
  replicasetList: replicasets {
    uuid
    status
    roles
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
      uri
      status
      message
      replicaset {
        uuid
      }
      labels {
        name
        value
      }
    }
  }
}
`;


export const serverStatQuery = gql`
query serverStat {
  serverStat: servers {
    uuid
    uri
    statistics {
      quotaSize: quota_size
      arenaUsed: arena_used
    }
  }
}`;

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

export const joinMutation = gql`
mutation join (
  $uri: String!,
  $uuid: String!
) {
  joinServerResponse: join_server(
    uri: $uri
    replicaset_uuid: $uuid
  )
}
`;

export const createReplicasetMutation = gql`
mutation createReplicaset (
  $uri: String!,
  $roles: [String!]
) {
  createReplicasetResponse: join_server(
    uri: $uri
    roles: $roles
  )
}
`;

export const expelMutation = gql`
mutation expel (
  $uuid: String!
) {
  expelServerResponse: expel_server(
    uuid: $uuid
  )
}
`;

export const editReplicasetMutation = gql`
mutation editReplicaset (
  $uuid: String!,
  $roles: [String!],
  $master: [String!]!,
  $weight: Float
) {
  editReplicasetResponse: edit_replicaset(
    uuid: $uuid
    roles: $roles
    master: $master
    weight: $weight
  )
}
`;

export const joinSingleServerMutation = gql`
mutation joinSingleServer (
  $uri: String!
) {
  joinServerResponse: join_server(
    uri: $uri
    roles: ["vshard-router", "vshard-storage"]
  )
}
`;

export const changeFailoverMutation = gql`
mutation changeFailover (
  $enabled: Boolean!,
) {
  cluster {
    failover(
      enabled: $enabled
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
