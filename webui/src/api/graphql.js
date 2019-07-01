import { ApolloClient } from 'apollo-client'
import { HttpLink } from 'apollo-link-http'
import { InMemoryCache } from 'apollo-cache-inmemory'
// import { withClientState } from 'apollo-link-state'
// import { ApolloLink } from 'apollo-link'

const httpLink = new HttpLink({
  uri: process.env.REACT_APP_GRAPHQL_API_ENDPOINT,
  credentials: 'include',
});

const cache = new InMemoryCache({
  addTypename: false
});

const client = new ApolloClient({
  link: httpLink,
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
    }
  },
});

export default {
  fetch(query, variables = {}) {
    return client.query({query, variables: variables}).then(r => r.data);
  },
  mutate(mutation, variables = {}) {
    return client.mutate({mutation, variables: variables}).then(r => r.data);
  },
};

export const isGraphqlErrorResponse
  = error =>
    Array.isArray(error.graphQLErrors)
    && error.graphQLErrors.length > 0
    && 'message' in error.graphQLErrors[0];

export const getGraphqlErrorMessage
  = error =>
    (Array.isArray(error.graphQLErrors)
    && error.graphQLErrors.length > 0
    && error.graphQLErrors[0].message) || 'GraphQL error with empty message';

export const isGraphqlAccessDeniedError
  = error =>
    isGraphqlErrorResponse(error) && getGraphqlErrorMessage(error) === 'Unauthorized';
