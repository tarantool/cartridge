import { getGraphqlErrorMessage, isGraphqlErrorResponse } from 'src/api/graphql';
import { getAxiosErrorMessage, getRestErrorMessage, isAxiosError, isRestErrorResponse } from 'src/api/rest';

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

export const SERVER_NOT_REACHABLE_ERROR_TYPE = 'SERVER_NOT_REACHABLE_ERROR_TYPE';
