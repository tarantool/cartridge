import { ApolloClient } from 'apollo-client'
import { HttpLink } from 'apollo-link-http'
import { InMemoryCache } from 'apollo-cache-inmemory'
// import { withClientState } from 'apollo-link-state'
// import { ApolloLink } from 'apollo-link'

const httpLink = new HttpLink({
  uri: process.env.REACT_APP_GRAPHQL_API_ENDPOINT,
  credentials: 'include',
});

const client = new ApolloClient({
  link: httpLink,
  cache: new InMemoryCache(),
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
    Array.isArray(error) && error.length === 1 && Object.keys(error[0]).length === 1 && 'message' in error[0];

export const getGraphqlErrorMessage
  = error =>
    (Array.isArray(error) && error.length === 1 && error[0].message) || 'GraphQL error with empty message';

export const isGraphqlAccessDeniedError
  = error =>
    isGraphqlErrorResponse(error) && getGraphqlErrorMessage(error) === 'Unauthorized';
