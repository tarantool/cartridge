/* eslint-disable no-console */
import { forward, guard } from 'effector';

import { not } from './utils';
import {
  $connectionAlive,
  AppGate,
  appClosedEvent,
  appOpenedEvent,
  consoleLogEvent,
  consoleLogFx,
  domain,
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

guard({
  clock: setConnectionAliveEvent,
  source: domain.createStore(true),
  filter: $connectionAlive.map(not),
  target: $connectionAlive,
});

guard({
  clock: setConnectionDeadEvent,
  source: domain.createStore(false),
  filter: $connectionAlive,
  target: $connectionAlive,
});

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
