import { forward, guard } from 'effector';

import { app } from 'src/models';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $selectedServerExpelModalServer,
  $selectedServerExpelModalUri,
  serverExpelEvent,
  serverExpelFx,
  serverExpelModalCloseEvent,
  serverExpelModalOpenEvent,
} from '.';

const { notifyErrorEvent, notifySuccessEvent } = app;
const { passResultPathOnEvent } = app.utils;

guard({
  source: $selectedServerExpelModalServer,
  clock: serverExpelEvent,
  filter: Boolean,
  target: serverExpelFx,
});

forward({
  from: serverExpelFx.done,
  to: refreshServerListAndClusterEvent,
});

forward({
  from: serverExpelFx.finally,
  to: serverExpelModalCloseEvent,
});

forward({
  from: serverExpelFx.done.map(() => 'Expel is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: serverExpelFx.failData.map((error) => ({
    error,
    title: 'Server expel error',
  })),
  to: notifyErrorEvent,
});

// stores
$selectedServerExpelModalUri
  .on(serverExpelModalOpenEvent, passResultPathOnEvent('uri'))
  .reset(serverExpelModalCloseEvent)
  .reset(clusterPageCloseEvent);
