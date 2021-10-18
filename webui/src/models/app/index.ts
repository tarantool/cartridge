import { createGate } from 'effector-react';

import { isGraphqlErrorResponse } from 'src/api/graphql';
import { formatGraphqlError } from 'src/misc/graphqlErrorNotification';
import { isNetworkError } from 'src/misc/isNetworkError';

import { domain } from './domain';
import * as messages from './messages';
import type { AppNotifyErrorPayload, AppNotifyErrorPayloadProps, AppNotifyPayload, Maybe } from './types';
import * as utils from './utils';
import * as variables from './variables';
import { yup } from './yup';

// exports
export { utils, variables, domain, yup, messages };

// gates
export const AppGate = createGate('AppGate');

// events
export const appOpenedEvent = domain.createEvent('app opened event');
export const appClosedEvent = domain.createEvent('app closed event');

export const notifyEvent = domain.createEvent<Maybe<AppNotifyPayload>>('notify event');

export const notifyErrorEvent = notifyEvent.prepend<AppNotifyErrorPayload>((props) => {
  const { error, title, timeout }: AppNotifyErrorPayloadProps = utils.isError(props) ? { error: props } : props;

  if (isNetworkError(error)) return;

  if (isGraphqlErrorResponse(error)) {
    const { errorStack, message, markdown } = formatGraphqlError(error);

    return {
      title: title || 'GraphQL error',
      message,
      details: errorStack ? markdown : null,
      type: 'error',
      timeout,
    };
  }

  return {
    title: title || 'Error',
    message: error.message,
    type: 'error',
    timeout,
  };
});

export const notifySuccessEvent = notifyEvent.prepend<string>((message) => ({
  title: 'Successful!',
  type: 'success',
  message,
}));

// effects
export const notifyFx = domain.createEffect<Maybe<AppNotifyPayload>, void>('notify', {
  handler: (props) => {
    if (!props) {
      return;
    }

    const { title, message, type = 'success', timeout = 5000 } = props;
    window.tarantool_enterprise_core.notify({
      title,
      message,
      type,
      timeout,
    });
  },
});

// other
export const tryCatchWithNotify = (callback: () => unknown) => {
  try {
    callback();
  } catch (error) {
    if (utils.isError(error)) {
      notifyErrorEvent(error);
    }
  }
};
