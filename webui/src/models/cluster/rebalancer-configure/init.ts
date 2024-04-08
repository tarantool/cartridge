import { combine, forward, guard } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import {
  $selectedRebalancer,
  $selectedRebalancerUuid,
  RebalancerStringValue,
  changeRebalancerEvent,
  editRebalancerFx,
  rebalancerModalCloseEvent,
  rebalancerModalOpenEvent,
  saveRebalancerEvent,
} from '.';

const { notifySuccessEvent, notifyErrorEvent } = app;

$selectedRebalancerUuid.on(rebalancerModalOpenEvent, (_, { uuid }) => uuid ?? null).reset(rebalancerModalCloseEvent);

$selectedRebalancer
  .on(rebalancerModalOpenEvent, (_, { rebalancer }) => {
    return rebalancer === true ? 'true' : rebalancer === false ? 'false' : 'unset';
  })
  .on(changeRebalancerEvent, (state, payload) => {
    return payload === 'unset' || payload === 'true' || payload === 'false' ? payload : state;
  })
  .reset(rebalancerModalCloseEvent);

editRebalancerFx.use(({ uuid, rebalancer }) =>
  graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, rebalancer: rebalancer === 'true' ? true : rebalancer === 'false' ? false : null }],
  })
);

guard({
  source: combine($selectedRebalancer, $selectedRebalancerUuid, (rebalancer, uuid) =>
    rebalancer && uuid ? { uuid, rebalancer } : null
  ),
  clock: saveRebalancerEvent,
  target: editRebalancerFx,
  filter: (
    value
  ): value is {
    uuid: string;
    rebalancer: RebalancerStringValue;
  } => value !== null,
});

forward({
  from: editRebalancerFx.done.map(() => 'Edit is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: editRebalancerFx.done,
  to: rebalancerModalCloseEvent,
});

forward({
  from: editRebalancerFx.failData,
  to: notifyErrorEvent,
});
