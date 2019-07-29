import { isGraphqlErrorResponse, getGraphqlErrorMessage } from 'src/api/graphql';
import { isRestErrorResponse, getRestErrorMessage, isAxiosError, getAxiosErrorMessage } from 'src/api/rest';

export const getErrorMessage = error => {
  switch (true) {
    case isGraphqlErrorResponse(error):
      return getGraphqlErrorMessage(error);
    case isRestErrorResponse(error):
      return getRestErrorMessage(error);
    case isAxiosError(error):
      return getAxiosErrorMessage(error);
    default:
      return error.message || error.toString();
  }
};

export const isDeadServerError = error => {
  return isRestErrorResponse(error)
    && (error.responseText === '' || /^Proxy error:.+ECONNREFUSED/.test(error.response));
};

export const SERVER_NOT_REACHABLE_ERROR_TYPE = 'SERVER_NOT_REACHABLE_ERROR_TYPE';
