import { forward, guard, sample } from 'effector';

import { app } from 'src/models';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import { editReplicasetFx, synchronizeReplicasetConfigureLocationFx } from './effects';
import {
  $replicasetConfigureModalVisible,
  $selectedReplicasetConfigureUuid,
  ClusterReplicasetConfigureGate,
  editReplicasetEvent,
  replicasetConfigureModalCloseEvent,
  replicasetConfigureModalOpenEvent,
} from '.';

const { notifySuccessEvent, notifyErrorEvent } = app;
const { not, mapModalOpenedClosedEventPayload, passResultPathOnEvent } = app.utils;

guard({
  source: ClusterReplicasetConfigureGate.open,
  filter: $replicasetConfigureModalVisible.map(not),
  target: replicasetConfigureModalOpenEvent,
});

forward({
  from: ClusterReplicasetConfigureGate.close,
  to: replicasetConfigureModalCloseEvent,
});

forward({
  from: editReplicasetEvent,
  to: editReplicasetFx,
});

forward({
  from: replicasetConfigureModalOpenEvent.map(mapModalOpenedClosedEventPayload(true)),
  to: synchronizeReplicasetConfigureLocationFx,
});

sample({
  source: $selectedReplicasetConfigureUuid.map((uuid) => ({ uuid })).map(mapModalOpenedClosedEventPayload(false)),
  clock: replicasetConfigureModalCloseEvent,
  target: synchronizeReplicasetConfigureLocationFx,
});

forward({
  from: editReplicasetFx.done,
  to: [replicasetConfigureModalCloseEvent, refreshServerListAndClusterEvent],
});

forward({
  from: editReplicasetFx.done.map(() => 'Edit is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: editReplicasetFx.failData,
  to: notifyErrorEvent,
});

$selectedReplicasetConfigureUuid
  .on(replicasetConfigureModalOpenEvent, passResultPathOnEvent('uuid'))
  .reset(replicasetConfigureModalCloseEvent)
  .reset(clusterPageCloseEvent);
