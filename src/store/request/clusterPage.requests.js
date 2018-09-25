import graphql from 'src/api/graphql';
import rest from 'src/api/rest';

const filterServerStat = response => {
  const serverStat = response.serverStat.filter(stat => stat.uuid);
  return {
    ...response,
    serverStat
  };
};

export function getPageData() {
  const graph = `
    query {
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
        servers {
          uuid
          alias
          uri
          status
          message
          replicaset {
            uuid
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
    }`;
  return graphql.fetch(graph)
    .then(filterServerStat);
}

/**
 * @param {Object} [params]
 * @param {string} [params.shouldRequestStat]
 */
export function refreshLists(params = {}) {
  const graph = `
    query {
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
        servers {
          uuid
          alias
          uri
          status
          message
          replicaset {
            uuid
          }
        }
      }
      ${params.shouldRequestStat
        ? `
          serverStat: servers {
            uuid
            uri
            statistics {
              quotaSize: quota_size
              arenaUsed: arena_used
            }
          }`
        : ''}
    }`;
  return graphql.fetch(graph)
    .then(params.shouldRequestStat ? filterServerStat : null);
}

export function getServerStat() {
  const graph = `
    query {
      serverStat: servers {
        uuid
        uri
        statistics {
          quotaSize: quota_size
          arenaUsed: arena_used
        }
      }
    }`;
  return graphql.fetch(graph)
    .then(filterServerStat);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 */
export function probeServer(params) {
  const graph = `
    mutation(
      $uri: String!
    ) {
      probeServerResponse: probe_server(
        uri: $uri
      )
    }`;
  return graphql.fetch(graph, params);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 * @param {string} params.uuid
 */
export function joinServer(params) {
  const graph = `
    mutation(
      $uri: String!,
      $uuid: String!
    ) {
      joinServerResponse: join_server(
        uri: $uri
        replicaset_uuid: $uuid
      )
    }`;
  return graphql.fetch(graph, params);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 * @param {string[]} params.roles
 */
export function createReplicaset(params) {
  const graph = `
    mutation(
      $uri: String!,
      $roles: [String!]
    ) {
      createReplicasetResponse: join_server(
        uri: $uri
        roles: $roles
      )
    }`;
  return graphql.fetch(graph, params);
}

/**
 * @param {Object} params
 * @param {string} params.uuid
 */
export function expellServer(params) {
  const graph = `
    mutation(
      $uuid: String!
    ) {
      expellServerResponse: expell_server(
        uuid: $uuid
      )
    }`;
  return graphql.fetch(graph, params);
}

/**
 * @param {Object} params
 * @param {string} params.uuid
 * @param {string[]} params.roles
 */
export function editReplicaset(params) {
  const graph = `
    mutation(
      $uuid: String!,
      $roles: [String!]
    ) {
      editReplicasetResponse: edit_replicaset(
        uuid: $uuid
        roles: $roles
      )
    }`;
  return graphql.fetch(graph, params);
}
/**
 * @param {Object} params
 * @param {string} params.uri
 */
export function joinSingleServer(params) {
  const graph = `
    mutation (
      $uri: String!
    ) {
    joinServerResponse: join_server(
      uri: $uri
      roles: ["vshard-router", "vshard-storage"]
    )
  }`;
  return graphql.fetch(graph, params);
}

export async function uploadConfig(params) {
  return rest.post('/config', params.data)
    .then(response => {
      console.log(response);
      return response;
    });
}

export function applyTestConfig() {
  const graph = `
    mutation {
      applyTestConfigResponse: cluster {
        load_config_example
      }
    }`;
  return graphql.fetch(graph);
}
