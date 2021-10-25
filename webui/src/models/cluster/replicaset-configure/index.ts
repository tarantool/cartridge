import { combine, sample } from 'effector';
import { createGate } from 'effector-react';

import { EditReplicasetInput } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import { $serverList, selectors } from '../server-list';
import { editReplicasetFx } from './effects';
import type { ClusterReplicasetConfigureGateProps } from './types';

// gates
export const ClusterReplicasetConfigureGate = createGate<ClusterReplicasetConfigureGateProps>(
  'ClusterReplicasetConfigureGate'
);

// events
export const replicasetConfigureModalOpenEvent = app.domain.createEvent<ClusterReplicasetConfigureGateProps>(
  'replicaset configure modal open event'
);
export const replicasetConfigureModalCloseEvent = app.domain.createEvent('replicaset configure modal close event');
export const editReplicasetEvent = app.domain.createEvent<EditReplicasetInput>('edit replicaset event');

// stores
export const $selectedReplicasetConfigureUuid = app.domain.createStore<string>('');

export const $selectedReplicasetConfigureReplicaset = sample({
  source: [$serverList, $selectedReplicasetConfigureUuid],
  fn: ([serverList, uuid]) => selectors.replicasetGetByUuid(serverList, uuid) ?? null,
});

export const $replicasetConfigureModalVisible = $selectedReplicasetConfigureReplicaset.map(Boolean);

// computed
export const $replicasetConfigureModal = combine({
  replicaset: $selectedReplicasetConfigureReplicaset,
  visible: $replicasetConfigureModalVisible,
  pending: editReplicasetFx.pending,
});
