import graphql from 'src/api/graphql';
import rest from 'src/api/rest';
import { getClusterSelf } from 'src/store/request/app.requests';
import {
  bootstrapMutation, changeFailoverMutation,
  createReplicasetMutation,
  editReplicasetMutation,
  expelMutation,
  joinMutation,
  joinSingleServerMutation,
  listQuery,
  listQueryWithoutStat,
  pageQuery,
  probeMutation,
  serverStatQuery
} from "./queries.graphql";

const filterServerStat = response => {
  const serverStat
    = response.serverStat.filter(stat => stat.uuid && stat.statistics && ! Array.isArray(stat.statistics));
  return {
    ...response,
    serverStat
  };
};

export function getPageData() {
  return graphql.fetch(pageQuery)
    .then(filterServerStat);
}

/**
 * @param {Object} [params]
 * @param {string} [params.shouldRequestStat]
 */
export function refreshLists(params = {}) {
  const graph = params.shouldRequestStat ? listQuery : listQueryWithoutStat;
  return graphql.fetch(graph)
    .then(params.shouldRequestStat ? filterServerStat : null);
}

export function getServerStat() {
  return graphql.fetch(serverStatQuery)
    .then(filterServerStat);
}

export function bootstrapVshard(params) {
  return graphql.mutate(bootstrapMutation, params);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 */
export function probeServer(params) {
  return graphql.mutate(probeMutation, params);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 * @param {string} params.uuid
 */
export function joinServer(params) {
  return graphql.mutate(joinMutation, params);
}

/**
 * @param {Object} params
 * @param {string} params.uri
 * @param {string[]} params.roles
 */
export function createReplicaset(params) {
  return graphql.mutate(createReplicasetMutation, params);
}

/**
 * @param {Object} params
 * @param {string} params.uuid
 */
export function expelServer(params) {
  return graphql.mutate(expelMutation, params);
}

/**
 * @param {Object} params
 * @param {string} params.uuid
 * @param {string[]} params.roles
 * @param {string[]} params.master
 */
export function editReplicaset(params) {
  return graphql.mutate(editReplicasetMutation, params);
}
/**
 * @param {Object} params
 * @param {string} params.uri
 */
export function joinSingleServer(params) {
  return graphql.mutate(joinSingleServerMutation, params);
}

export async function uploadConfig(params) {
  console.log(params);

  return rest.put(process.env.REACT_APP_CONFIG_ENDPOINT, params.data, {
    headers: { 'Content-Type': 'application/yaml;charset=UTF-8' },
  });
}

/**
 * @param {Object} params
 * @param {boolean} params.enabled
 */
export async function changeFailover(params) {
  const changeFailoverResponse = await graphql.mutate(changeFailoverMutation, params);
  const clusterSelfResponse = await getClusterSelf();
  return {
    changeFailoverResponse: {
      changeFailover: changeFailoverResponse,
      clusterSelf: clusterSelfResponse,
    },
  };
}

// /**
//  * @param {Object} params
//  * @param {boolean} params.enabled
//  */
// export async function changeFailover(params) {
//   const graph = `
//     mutation (
//       $enabled: Boolean!,
//     ) {
//       cluster {
//         failover(
//           enabled: $enabled
//         )
//       }
//     }`;
//   const changeFailoverResponse = await graphql.fetch(graph, params);
//   const clusterSelfResponse = await getClusterSelf();
//   return {
//     changeFailoverResponse: {
//       changeFailover: changeFailoverResponse,
//       clusterSelf: clusterSelfResponse,
//     },
//   };
// }
