/* eslint-disable no-console */
import { forward } from 'effector';

import { falseL, trueL } from './utils';
import {
  $connectionAlive,
  AppGate,
  appClosedEvent,
  appOpenedEvent,
  consoleLogEvent,
  consoleLogFx,
  notifyEvent,
  notifyFx,
  setConnectionAliveEvent,
  setConnectionDeadEvent,
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

$connectionAlive.on(setConnectionAliveEvent, trueL).on(setConnectionDeadEvent, falseL);

// effects
notifyFx.use((props) => {
  if (!props) {
    return;
  }

  const { title, message, type = 'success', timeout = 5000, details } = props;
  window.tarantool_enterprise_core.notify({
    title,
    message,
    type,
    timeout,
    details,
  });
});

consoleLogFx.use((props) => void console.log(props));
