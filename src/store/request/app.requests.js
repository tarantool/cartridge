import graphql from 'src/api/graphql';
import rest from 'src/api/rest';

export async function getClusterSelf() {
  const graph = `
    query {
      cluster {
        clusterSelf: self {
          uri: uri
          uuid: uuid
        }
        failover
      }
    }`;
  const response = await graphql.fetch(graph);
  const { clusterSelf, failover } = response.cluster;
  return {
    clusterSelf: {
      ...clusterSelf,
      uuid: clusterSelf.uuid || null,
      configured: !!clusterSelf.uuid,
    },
    failover,
  };
}

export async function getAnonymousAllowed() {
  const graph = `
    query {
      user {
        isAnonymousAllowed: is_anonymous_allowed
      }
    }`;
  const response = await graphql.fetch(graph);
  return {
    isAnonymousAllowed: response.user.isAnonymousAllowed,
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

/**
 * @param {Object} params
 * @param {string} params.email
 * @param {string} params.password
 */
export async function login(params) {
  let result;

  try {
    const loginResponse = await rest.post('/login', params);
    result = {
      authenticated: loginResponse.data.result === 'success',
      loginResponse: loginResponse.data,
    };
  }
  catch (error) {
    if (error.response.status === 403) {
      return {
        authenticated: false,
        loginResponse: error.response.data,
      };
    }
    throw error;
  }

  if (result.authenticated) {
    const clusterSelfResponse = await getClusterSelf();
    result.clusterSelf = clusterSelfResponse.clusterSelf;
  }

  return result;
}

export async function logout() {
  const response = await rest.get('/logout');
  return {
    authenticated: false,
    loginResponse: null,
    logoutResponse: response.data,
  };
}

export async function denyAnonymous() {
  const graph = `
    mutation {
      user {
        denyAnonymous: deny_anonymous
      }
    }`;
  await graphql.fetch(graph);
  return {
    isAnonymousAllowed: false,
  };
}

export async function allowAnonymous() {
  const graph = `
    mutation {
      user {
        allowAnonymous: allow_anonymous
      }
    }`;
  await graphql.fetch(graph);
  return {
    isAnonymousAllowed: true,
  };
}
