import graphql from 'src/api/graphql';
import rest from 'src/api/rest';
import {authQuery, turnAuthMutation} from "./queries.graphql";

export async function getAuthState() {
  const { cluster } = await graphql.fetch(authQuery);
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
  const { cluster } = await graphql.mutate(turnAuthMutation, {enabled});
  return cluster.authParams;
}
