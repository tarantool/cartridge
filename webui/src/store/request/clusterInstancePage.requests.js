import graphql from 'src/api/graphql';

const descriptionsByName = ({ fields = [] } = {}) => fields.reduce((acc, item) => {
  acc[item.name] = item.description;
  return acc;
}, {})

function boxInfoQuery(instanceUUID) {
  return `
    servers(uuid: "${instanceUUID}") {
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
  `;
}

export function getInstanceData({ instanceUUID }) {
  const graph = `
    query {
      ${boxInfoQuery(instanceUUID)}

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

  return graphql.fetch(graph)
    .then(({
      servers,
      descriptionGeneral,
      descriptionNetwork,
      descriptionReplication,
      descriptionStorage,
    }) => {
      const {
        alias,
        boxinfo = {},
        message,
        replicaset: {
          active_master: {
            uuid: masterUUID
          },
          master: {
            uuid: activeMasterUUID
          },
          roles
        },
        status,
        uri
      } = servers[0];

      return {
        alias,
        boxinfo,
        message,
        masterUUID,
        activeMasterUUID,
        roles,
        status,
        uri,
        descriptions: {
          general: descriptionsByName(descriptionGeneral),
          network: descriptionsByName(descriptionNetwork),
          replication: descriptionsByName(descriptionReplication),
          storage: descriptionsByName(descriptionStorage)
        }
      }
    });
}

export function refreshInstanceData({ instanceUUID }) {
  const graph = `
    query {
      ${boxInfoQuery(instanceUUID)}
    }
  `;

  return graphql.fetch(graph)
    .then(({ servers }) => ({
      boxinfo: servers[0].boxinfo || {},
    }));
}
