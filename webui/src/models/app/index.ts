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

// stores
export const $connectionAlive = domain.createStore(true);
export const $authSessionChangeModalVisibility = domain.createStore(false);

// events
export const appOpenedEvent = domain.createEvent('app opened event');
export const appClosedEvent = domain.createEvent('app closed event');

export const setConnectionAliveEvent = domain.createEvent<boolean>('set connection alive event');
export const setConnectionDeadEvent = domain.createEvent<boolean>('set connection dead event');
export const authAccessDeniedEvent = domain.createEvent('auth access denied event');

export const notifyEvent = domain.createEvent<Maybe<AppNotifyPayload>>('notify event');
export const consoleLogEvent = domain.createEvent<unknown>('console.log event');

export const initAuthSessionChangeEvent = domain.createEvent('init auth session change event');
export const triggerAuthSessionChangeEvent = domain.createEvent('trigger auth session event');
export const changeAuthSessionEvent = domain.createEvent('change auth session event');
export const showAuthSessionChangeModalEvent = domain.createEvent('show auth session change event');

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
export const notifyFx = domain.createEffect<Maybe<AppNotifyPayload>, void>('notify');
export const consoleLogFx = domain.createEffect<unknown, void>('console.log');

export const initAuthSessionChangeFx = domain.createEffect('init auth session change');
export const triggerAuthSessionChangeFx = domain.createEffect('trigger auth session change');
export const changeAuthSessionFx = domain.createEffect('change auth session');

// other
export const tryCatchWithNotify = (callback: () => void) => {
  try {
    callback();
  } catch (error) {
    if (utils.isError(error)) {
      notifyErrorEvent(error);
    }
  }
};
