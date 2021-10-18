import { forward, guard, sample } from 'effector';

import { app } from 'src/models';

import { clusterPageClosedEvent } from '../page';
import { refreshServerListAndSetDirtyEvent } from '../server-list';
import { editReplicasetFx, synchronizeReplicasetConfigureLocationFx } from './effects';
import {
  $isReplicasetConfigureModalOpen,
  $selectedReplicasetConfigureUuid,
  ClusterReplicasetConfigureGate,
  editReplicasetEvent,
  replicasetConfigureModalCloseEvent,
  replicasetConfigureModalOpenEvent,
} from '.';

const { notifySuccessEvent, notifyErrorEvent } = app;
const { not, mapModalOpenedClosedEventPayload } = app.utils;

guard({
  source: ClusterReplicasetConfigureGate.open,
  filter: $isReplicasetConfigureModalOpen.map(not),
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
  source: $selectedReplicasetConfigureUuid.map((uuid) => ({ props: { uuid }, open: false })),
  clock: replicasetConfigureModalCloseEvent,
  target: synchronizeReplicasetConfigureLocationFx,
});

forward({
  from: editReplicasetFx.done,
  to: [replicasetConfigureModalCloseEvent, refreshServerListAndSetDirtyEvent],
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
  .on(replicasetConfigureModalOpenEvent, (_, { uuid }) => uuid)
  .reset(replicasetConfigureModalCloseEvent)
  .reset(clusterPageClosedEvent);
