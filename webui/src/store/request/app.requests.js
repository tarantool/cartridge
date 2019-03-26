import graphql from 'src/api/graphql';

export async function getClusterSelf() {
  const graph = `
    query {
      cluster {
        clusterSelf: self {
          uri: uri
          uuid: uuid
        }
        failover
        knownRoles: known_roles
        can_bootstrap_vshard
        vshard_bucket_count
        authParams: auth_params {
          enabled
          implements_check_password
          implements_get_user
          implements_add_user
          implements_edit_user
          username
        }
      }
    }
  `;
  const response = await graphql.fetch(graph);

  const {
    clusterSelf,
    failover,
    knownRoles,
    can_bootstrap_vshard,
    vshard_bucket_count,
    authParams
  } = response.cluster;

  return {
    clusterSelf: {
      ...clusterSelf,
      uuid: clusterSelf.uuid || null,
      configured: !!clusterSelf.uuid,
      knownRoles,
      can_bootstrap_vshard,
      vshard_bucket_count,
      authParams
    },
    failover,
  };
}

/**
 * @param {Object} params
 * @param {string} [params.uri]
 * @param {string} params.text
 */
export function evalString(params) {
  const graph = `
    mutation(
      $uri: String,
      $text: String
    ) {
      cluster {
        evalStringResponse: evaluate(
          uri: $uri
          eval: $text
        )
      }
    }`;
  return graphql.fetch(graph, params)
    .then(response => {
      return {
        evalStringResponse: response.cluster.evalStringResponse,
      };
    });
}
