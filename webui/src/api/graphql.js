import { InMemoryCache } from 'apollo-cache-inmemory';
import { ApolloClient } from 'apollo-client';
import { from } from 'apollo-link';
import { HttpLink } from 'apollo-link-http';

import { getApiEndpoint } from 'src/apiEndpoints';

const httpLink = new HttpLink({
  uri: getApiEndpoint('GRAPHQL_API_ENDPOINT'),
  credentials: 'include',
});

const cache = new InMemoryCache({
  addTypename: false,
});

const client = new ApolloClient({
  link: from([
    window.tarantool_enterprise_core.apiMethods.apolloLinkOnError,
    window.tarantool_enterprise_core.apiMethods.apolloLinkAfterware,
    window.tarantool_enterprise_core.apiMethods.apolloLinkMiddleware,
    httpLink,
  ]),
  cache,
  defaultOptions: {
    query: {
      fetchPolicy: 'no-cache',
    },
    mutate: {
      fetchPolicy: 'no-cache',
    },
    watchQuery: {
      fetchPolicy: 'no-cache',
    },
  },
});

export default {
  fetch(query, variables = {}) {
    return client.query({ query, variables: variables }).then((r) => r.data);
  },
  mutate(mutation, variables = {}) {
    return client.mutate({ mutation, variables: variables }).then((r) => r.data);
  },
};

export const getGraphqlError = (error) =>
  (Array.isArray(error.graphQLErrors) && error.graphQLErrors.length > 0 && error.graphQLErrors[0]) || null;

export const isGraphqlErrorResponse = (error) => {
  const gqlError = getGraphqlError(error);
  return !!(gqlError && 'message' in gqlError);
};

export const isNetworkErrorError = (error) => {
  return Boolean(error && error.message === 'Network Error');
};

export const isGraphqlAccessDeniedError = (error) =>
  (isGraphqlErrorResponse(error) && getGraphqlErrorMessage(error) === 'Unauthorized') ||
  (error.networkError && error.networkError.statusCode === 401);

export const getGraphqlErrorMessage = (error) => {
  if (isNetworkErrorError(error)) {
    return 'Cannot connect to server. Please try again later.';
  }

  const gqlError = getGraphqlError(error);
  if (gqlError && gqlError.message) {
    return gqlError.message;
  }

  return 'GraphQL error with empty message';
};
