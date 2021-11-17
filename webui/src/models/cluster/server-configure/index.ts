import { combine } from 'effector';
import { createGate } from 'effector-react';

import { EditTopologyMutation } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import { $clusterPage } from '../page';
import type { ClusterServeConfigureGateProps, CreateReplicasetProps, JoinReplicasetProps } from './types';

const { some } = app.utils;

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
export const $serverConfigureModalVisible = $selectedServerConfigureUri.map(Boolean);

// effects

export const createReplicasetFx = app.domain.createEffect<CreateReplicasetProps, EditTopologyMutation>(
  'create replicaset'
);

export const joinReplicasetFx = app.domain.createEffect<JoinReplicasetProps, EditTopologyMutation>('join replicaset');

export const synchronizeServerConfigureLocationFx = app.domain.createEffect<
  { props: ClusterServeConfigureGateProps; open: boolean },
  void
>('synchronize server configure location effect');

// computed
export const $serverConfigureModal = combine({
  uri: $selectedServerConfigureUri,
  visible: $serverConfigureModalVisible,
  pending: combine([createReplicasetFx.pending, joinReplicasetFx.pending]).map(some),
  loading: $clusterPage.map(({ ready }) => !ready),
});
