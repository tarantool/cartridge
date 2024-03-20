import { combine, forward, guard } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { changeRebalancerModeMutation } from 'src/store/request/queries.graphql';

import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $selectedRebalancerMode,
  $selectedRebalancerName,
  changeRebalancerModeEvent,
  editRebalancerModeFx,
  rebalancerModeModalCloseEvent,
  rebalancerModeModalOpenEvent,
  saveRebalancerModeEvent,
} from '.';

const { notifySuccessEvent, notifyErrorEvent } = app;

$selectedRebalancerName.on(rebalancerModeModalOpenEvent, (_, { name }) => name).reset(rebalancerModeModalCloseEvent);

$selectedRebalancerMode
  .on(rebalancerModeModalOpenEvent, (_, { rebalancer_mode }) => rebalancer_mode)
  .on(changeRebalancerModeEvent, (_, payload) => payload)
  .reset(rebalancerModeModalCloseEvent);

editRebalancerModeFx.use(({ name, rebalancer_mode }) =>
  graphql.mutate(changeRebalancerModeMutation, {
    name,
    rebalancer_mode,
  })
);

guard({
  source: combine($selectedRebalancerMode, $selectedRebalancerName, (rebalancer_mode, name) =>
    rebalancer_mode && name ? { name, rebalancer_mode } : null
  ),
  clock: saveRebalancerModeEvent,
  target: editRebalancerModeFx,
  filter: (
    value
  ): value is {
    name: string;
    rebalancer_mode: string;
  } => value !== null,
});

forward({
  from: editRebalancerModeFx.done.map(() => 'Edit is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: editRebalancerModeFx.done,
  to: rebalancerModeModalCloseEvent,
});

forward({
  from: editRebalancerModeFx.failData,
  to: notifyErrorEvent,
});

forward({
  from: editRebalancerModeFx.done,
  to: refreshServerListAndClusterEvent,
});
