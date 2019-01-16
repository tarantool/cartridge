const graphRequest = window.graphql(process.env.REACT_APP_GRAPHQL_API_ENDPOINT, {
  asJSON: true,
  method: 'post',
});

export default {
  fetch(graph, variables) {
    return graphRequest(graph)(variables);
  },
};

export const isGraphqlErrorResponse
  = error =>
    Array.isArray(error) && error.length === 1 && Object.keys(error[0]).length === 1 && 'message' in error[0];

export const getGraphqlErrorMessage
  = error =>
    error[0].message || 'GraphQL error with empty message';

export const isGraphqlAccessDeniedError
  = error =>
    isGraphqlErrorResponse(error) && getGraphqlErrorMessage(error) === 'Access denied';
