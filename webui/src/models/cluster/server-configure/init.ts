import { forward, guard, sample } from 'effector';
import core from '@tarantool.io/frontend-core';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent, paths } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $selectedServerConfigureUri,
  $serverConfigureModalVisible,
  ClusterServerConfigureGate,
  createReplicasetEvent,
  createReplicasetFx,
  joinReplicasetEvent,
  joinReplicasetFx,
  serverConfigureModalClosedEvent,
  serverConfigureModalOpenedEvent,
  synchronizeServerConfigureLocationFx,
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

// effects

createReplicasetFx.use(({ alias, roles, weight, all_rw, vshard_group, join_servers }) =>
  graphql.fetch(editTopologyMutation, {
    replicasets: [
      {
        alias: alias || null,
        roles,
        weight: weight || null,
        all_rw,
        vshard_group: vshard_group || null,
        join_servers,
      },
    ],
  })
);

joinReplicasetFx.use(({ uri, uuid }) =>
  graphql.fetch(editTopologyMutation, {
    replicasets: [{ uuid, join_servers: [{ uri }] }],
  })
);

synchronizeServerConfigureLocationFx.use(({ props, open }) => {
  const { history } = core;
  const {
    location: { search },
  } = history;

  if (open) {
    if (!search.includes(props.uri)) {
      history.push(paths.serverConfigure(props));
    }
  } else {
    if (search.includes(props.uri)) {
      history.push(paths.root());
    }
  }
});
