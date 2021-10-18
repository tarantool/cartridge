import { combine } from 'effector';
import { createGate } from 'effector-react';

import { app } from 'src/models';

import { $isClusterPageReady } from '../page';
import { createReplicasetFx, joinReplicasetFx } from './effects';
import type { ClusterServeConfigureGateProps, CreateReplicasetProps, JoinReplicasetProps } from './types';

const { not, some } = app.utils;

// gates
export const ClusterServerConfigureGate = createGate<ClusterServeConfigureGateProps>('ClusterServeConfigureGate');

// events
export const serverConfigureModalOpenedEvent = app.domain.createEvent<ClusterServeConfigureGateProps>(
  'server configure modal opened'
);
export const serverConfigureModalClosedEvent = app.domain.createEvent('server configure modal closed');
export const createReplicasetEvent = app.domain.createEvent<CreateReplicasetProps>('create replicaset event');
export const joinReplicasetEvent = app.domain.createEvent<JoinReplicasetProps>('join replicaset event');

// stores
export const $selectedServerConfigureUri = app.domain.createStore<string>('');
export const $selectedServerConfigureReplicaset = app.domain.createStore<string | null>(null);
export const $isServerConfigureModalOpen = $selectedServerConfigureUri.map(Boolean);

// computed
export const $serverConfigureModal = combine({
  uri: $selectedServerConfigureUri,
  visible: $isServerConfigureModalOpen,
  pending: combine([createReplicasetFx.pending, joinReplicasetFx.pending]).map(some),
  loading: $isClusterPageReady.map(not),
});
