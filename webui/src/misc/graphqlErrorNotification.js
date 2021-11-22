// @flow
import core from '@tarantool.io/frontend-core';

import { getGraphqlError, isGraphqlErrorResponse } from 'src/api/graphql';
import { isNetworkError } from 'src/misc/isNetworkError';

type FormattedGraphqlError = {
  errorClassName: string,
  errorStack: string,
  message: string,
  markdown: string,
};

export const formatGraphqlError = (error: Error): FormattedGraphqlError => {
  let errorClassName: string = '';
  let errorStack: string = '';
  let message: string = '';

  if (isGraphqlErrorResponse(error)) {
    const errorData = getGraphqlError(error);

    if (errorData && errorData.extensions) {
      errorClassName = errorData.extensions['io.tarantool.errors.class_name'];
      errorStack = errorData.extensions['io.tarantool.errors.stack'];
    }

    message = (errorClassName ? `${errorClassName}: ${errorData.message}` : errorData.message) || error.message;
  }

  const markdown = message + (errorStack ? '\n\n```\n' + errorStack + '\n```\n' : '');

  return {
    errorClassName,
    errorStack,
    message,
    markdown,
  };
};

export const graphqlErrorNotification = (error: Error, title?: string) => {
  if (isNetworkError(error)) return;

  const { errorStack, message, markdown } = formatGraphqlError(error);

  core.notify({
    title: title || 'GraphQL error',
    message,
    details: errorStack ? markdown : null,
    type: 'error',
    timeout: 5000,
  });
};
