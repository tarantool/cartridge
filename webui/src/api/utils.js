import { get as _get } from 'lodash';

export const getGraphqlError = (error) =>
  (Array.isArray(error.graphQLErrors) && error.graphQLErrors.length > 0 && error.graphQLErrors[0]) || null;

export const isGraphqlErrorResponse = (error) => {
  const gqlError = getGraphqlError(error);
  return !!(gqlError && 'message' in gqlError);
};

export const getGraphqlErrorMessage = (error) => {
  const gqlError = getGraphqlError(error);
  return (gqlError && gqlError.message) || 'GraphQL error with empty message';
};

export const isGraphqlAccessDeniedError = (error) =>
  (isGraphqlErrorResponse(error) && getGraphqlErrorMessage(error) === 'Unauthorized') ||
  (error.networkError && error.networkError.statusCode === 401);

export const isRestErrorResponse = (error) => error instanceof XMLHttpRequest;

export const getRestErrorMessage = (error) => error.responseText || 'XMLHttpRequest error with empty message';

export const isRestAccessDeniedError = (error) => isRestErrorResponse(error) && error.status === 401;

export const isAxiosError = (error) => !!_get(error, 'config.adapter', false);

export const getAxiosErrorMessage = (error) =>
  _get(error, 'response.data.class_name', false) && _get(error, 'response.data.err', false)
    ? `${_get(error, 'response.data.class_name')}: ${_get(error, 'response.data.err')}`
    : error.message;

export const isDeadServerError = (error) => {
  return (
    isRestErrorResponse(error) && (error.responseText === '' || /^Proxy error:.+ECONNREFUSED/.test(error.response))
  );
};

export const isNetworkError = (error) => {
  return !!error.networkError;
};

export const getNetworkErrorMessage = (error) => {
  return error.networkError.bodyText || error.networkError.message;
};

export const getErrorMessage = (error) => {
  switch (true) {
    case isGraphqlErrorResponse(error):
      return getGraphqlErrorMessage(error);
    case isRestErrorResponse(error):
      return getRestErrorMessage(error);
    case isAxiosError(error):
      return getAxiosErrorMessage(error);
    case isNetworkError(error):
      return getNetworkErrorMessage(error);
    default:
      return error.message || error.toString();
  }
};
