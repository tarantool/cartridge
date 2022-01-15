/* eslint-disable no-console */
import { forward } from 'effector';
import { core } from '@tarantool.io/frontend-core';

import { AUTH_TRIGGER_SESSION_KEY } from 'src/constants';

import { falseL, trueL, tryNoCatch } from './utils';
import {
  $authSessionChangeModalVisibility,
  $connectionAlive,
  AppGate,
  appClosedEvent,
  appOpenedEvent,
  changeAuthSessionEvent,
  changeAuthSessionFx,
  consoleLogEvent,
  consoleLogFx,
  initAuthSessionChangeEvent,
  initAuthSessionChangeFx,
  notifyEvent,
  notifyFx,
  setConnectionAliveEvent,
  setConnectionDeadEvent,
  showAuthSessionChangeModalEvent,
  triggerAuthSessionChangeEvent,
  triggerAuthSessionChangeFx,
} from '.';

forward({
  from: AppGate.open,
  to: appOpenedEvent,
});

forward({
  from: AppGate.close,
  to: appClosedEvent,
});

forward({
  from: notifyEvent,
  to: notifyFx,
});

forward({
  from: consoleLogEvent,
  to: consoleLogFx,
});

forward({
  from: initAuthSessionChangeEvent,
  to: initAuthSessionChangeFx,
});

forward({
  from: triggerAuthSessionChangeEvent,
  to: triggerAuthSessionChangeFx,
});

forward({
  from: changeAuthSessionEvent,
  to: changeAuthSessionFx,
});

$connectionAlive.on(setConnectionAliveEvent, trueL).on(setConnectionDeadEvent, falseL);
$authSessionChangeModalVisibility.on(showAuthSessionChangeModalEvent, trueL);

// effects
notifyFx.use((props) => {
  if (!props) {
    return;
  }

  const { title, message, type = 'success', timeout = 5000, details } = props;
  core.notify({
    title,
    message,
    type,
    timeout,
    details,
  });
});

consoleLogFx.use((props) => void console.log(props));

initAuthSessionChangeFx.use(() =>
  tryNoCatch(() =>
    window.addEventListener('storage', (e: StorageEvent) => {
      if (e && e.key === AUTH_TRIGGER_SESSION_KEY) {
        showAuthSessionChangeModalEvent();
      }
    })
  )
);

triggerAuthSessionChangeFx.use(() =>
  tryNoCatch(() => localStorage.setItem(AUTH_TRIGGER_SESSION_KEY, `${Math.random()}`))
);

changeAuthSessionFx.use(() => void window.location.reload());
