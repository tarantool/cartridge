import {
  getErrorMessage,
  getNetworkErrorMessage,
  isDeadServerError,
  isNetworkError,
  isRestErrorResponse,
} from './utils';

export { getErrorMessage, getNetworkErrorMessage, isNetworkError, isRestErrorResponse, isDeadServerError };

export const SERVER_NOT_REACHABLE_ERROR_TYPE = 'SERVER_NOT_REACHABLE_ERROR_TYPE';
