import { InMemoryCache } from 'apollo-cache-inmemory';
import { ApolloClient } from 'apollo-client';
import { from } from 'apollo-link';
import { HttpLink } from 'apollo-link-http';

import { getApiEndpoint } from 'src/apiEndpoints';

import { getGraphqlError, getGraphqlErrorMessage, isGraphqlAccessDeniedError, isGraphqlErrorResponse } from './utils';

export { getGraphqlError, getGraphqlErrorMessage, isGraphqlAccessDeniedError, isGraphqlErrorResponse };

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
