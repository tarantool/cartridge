/* eslint-disable no-console */
import { forward, guard } from 'effector';

import { consoleLogFx, notifyFx } from './effects';
import { not } from './utils';
import {
  $connectionAlive,
  AppGate,
  appClosedEvent,
  appOpenedEvent,
  consoleLogEvent,
  domain,
  notifyEvent,
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
