import graphql from 'src/api/graphql';
import rest from 'src/api/rest';

export async function getAuthState() {
  const graph = `
    query {
      cluster {
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

  const { cluster } = await graphql.fetch(graph);
  return cluster.authParams;
}

/**
 * @param {Object} params
 * @param {string} params.username
 * @param {string} params.password
 */
export async function logIn(params) {
  const username = encodeURIComponent(params.username);
  const password = encodeURIComponent(params.password);
  let result;

  try {
    await rest.post(
      '/login',
      `username=${username}&password=${password}`,
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    );

    result = {
      authorized: true,
      error: null
    };
  } catch (error) {
    if (error.response.status === 403) {
      return {
        authorized: false,
        error: 'Authentication failed',
      };
    }
    throw error;
  }

  if (result.authorized) {
    const authStateResponse = await getAuthState();
    result = {
      ...result,
      ...authStateResponse
    }
  }

  return result;
}

export async function logOut() {
  await rest.post('/logout');
  return {
    authorized: false,
    error: null,
  };
}

export async function turnAuth({ enabled = true }) {
  const graph = `
    mutation {
      cluster {
        authParams: auth_params(enabled: ${enabled}) {
          enabled
        }
      }
    }
  `;

  const { cluster } = await graphql.fetch(graph);
  return cluster.authParams;
}
