import { forward, guard, sample } from 'effector';
import { core } from '@tarantool.io/frontend-core';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent, paths } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $replicasetConfigureModalVisible,
  $selectedReplicasetConfigureUuid,
  ClusterReplicasetConfigureGate,
  editReplicasetEvent,
  editReplicasetFx,
  replicasetConfigureModalCloseEvent,
  replicasetConfigureModalOpenEvent,
  synchronizeReplicasetConfigureLocationFx,
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

// effects
editReplicasetFx.use(
  ({ uuid, alias, roles, weight, all_rw, rebalancer, vshard_group, failover_priority, join_servers }) =>
    graphql.fetch(editTopologyMutation, {
      replicasets: [
        {
          uuid,
          alias,
          roles,
          weight,
          all_rw,
          vshard_group,
          failover_priority,
          join_servers,
          rebalancer: rebalancer ?? null,
        },
      ],
    })
);

synchronizeReplicasetConfigureLocationFx.use(({ props, open }) => {
  const { history } = core;
  const {
    location: { search },
  } = history;

  if (open) {
    if (!search.includes(props.uuid)) {
      history.push(paths.replicasetConfigure(props));
    }
  } else {
    if (search.includes(props.uuid)) {
      history.push(paths.root());
    }
  }
});
