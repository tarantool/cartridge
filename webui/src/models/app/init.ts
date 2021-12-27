/* eslint-disable no-console */
import { forward } from 'effector';
import { core } from '@tarantool.io/frontend-core';

import { falseL, trueL } from './utils';
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
  notifyEvent,
  notifyFx,
  setConnectionAliveEvent,
  setConnectionDeadEvent,
  showAuthSessionChangeModalEvent,
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

changeAuthSessionFx.use(() => void window.location.reload());
