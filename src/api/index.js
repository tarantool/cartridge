import { isGraphqlErrorResponse, getGraphqlErrorMessage } from 'src/api/graphql';
import { isRestErrorResponse, getRestErrorMessage } from 'src/api/rest';

export const getErrorMessage = error => {
  switch (true) {
    case isGraphqlErrorResponse(error):
      return getGraphqlErrorMessage(error);
    case isRestErrorResponse(error):
      return getRestErrorMessage(error);
    default:
        return error.message;
  }
};
