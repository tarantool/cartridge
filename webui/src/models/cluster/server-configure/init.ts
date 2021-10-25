import { forward, guard, sample } from 'effector';

import { app } from 'src/models';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import { createReplicasetFx, joinReplicasetFx, synchronizeServerConfigureLocationFx } from './effects';
import {
  $selectedServerConfigureUri,
  $serverConfigureModalVisible,
  ClusterServerConfigureGate,
  createReplicasetEvent,
  joinReplicasetEvent,
  serverConfigureModalClosedEvent,
  serverConfigureModalOpenedEvent,
} from '.';

const { notifyErrorEvent, notifySuccessEvent } = app;
const { not, mapModalOpenedClosedEventPayload, passResultPathOnEvent } = app.utils;

guard({
  source: ClusterServerConfigureGate.open,
  filter: $serverConfigureModalVisible.map(not),
  target: serverConfigureModalOpenedEvent,
});

forward({
  from: ClusterServerConfigureGate.close,
  to: serverConfigureModalClosedEvent,
});

forward({
  from: createReplicasetEvent,
  to: createReplicasetFx,
});

forward({
  from: joinReplicasetEvent,
  to: joinReplicasetFx,
});

forward({
  from: serverConfigureModalOpenedEvent.map(mapModalOpenedClosedEventPayload(true)),
  to: synchronizeServerConfigureLocationFx,
});

sample({
  source: $selectedServerConfigureUri.map((uri) => ({ uri })).map(mapModalOpenedClosedEventPayload(false)),
  clock: serverConfigureModalClosedEvent,
  target: synchronizeServerConfigureLocationFx,
});

forward({
  from: [createReplicasetFx.done, joinReplicasetFx.done],
  to: [serverConfigureModalClosedEvent, refreshServerListAndClusterEvent],
});

forward({
  from: createReplicasetFx.done.map(() => 'Create is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: joinReplicasetFx.done.map(() => 'Join is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: [createReplicasetFx.failData, joinReplicasetFx.failData],
  to: notifyErrorEvent,
});

// stories
$selectedServerConfigureUri
  .on(serverConfigureModalOpenedEvent, passResultPathOnEvent('uri'))
  .reset(serverConfigureModalClosedEvent)
  .reset(clusterPageCloseEvent);
