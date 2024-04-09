import { forward } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { changeFailoverMutation, getFailoverParams, getStateProviderStatus } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $failover,
  $failoverModalError,
  $failoverModalVisible,
  $stateProviderStatus,
  changeFailoverEvent,
  changeFailoverFx,
  failoverModalCloseEvent,
  failoverModalOpenEvent,
  getFailoverFx,
  getStateProviderStatusFx,
  stateProviderStatusGetEvent,
} from '.';

const { notifyEvent, notifyErrorEvent } = app;
const { trueL, passResultOnEvent, passErrorMessageOnEvent } = app.utils;

forward({
  from: failoverModalOpenEvent,
  to: getFailoverFx,
});

forward({
  from: stateProviderStatusGetEvent,
  to: getStateProviderStatusFx,
});

forward({
  from: changeFailoverEvent,
  to: changeFailoverFx,
});

forward({
  from: changeFailoverFx.done,
  to: [refreshServerListAndClusterEvent, failoverModalCloseEvent],
});

forward({
  from: changeFailoverFx.done.map((value) => ({
    title: 'Failover mode',
    message: value.result.cluster?.failover_params.mode ?? '',
  })),
  to: notifyEvent,
});

forward({
  from: getFailoverFx.failData,
  to: notifyErrorEvent,
});

forward({
  from: getStateProviderStatusFx.failData,
  to: notifyErrorEvent,
});

forward({
  from: getFailoverFx.fail,
  to: failoverModalCloseEvent,
});

// stores
$failover
  .on(getFailoverFx.doneData, passResultOnEvent)
  .reset(failoverModalOpenEvent)
  .reset(failoverModalCloseEvent)
  .reset(clusterPageCloseEvent);

$failoverModalError
  .on(changeFailoverFx.failData, passErrorMessageOnEvent)
  .reset(failoverModalOpenEvent)
  .reset(failoverModalCloseEvent)
  .reset(clusterPageCloseEvent);

$failoverModalVisible.on(failoverModalOpenEvent, trueL).reset(failoverModalCloseEvent).reset(clusterPageCloseEvent);

$stateProviderStatus
  .on(getStateProviderStatusFx.doneData, (_, payload) => {
    return payload.cluster.failover_state_provider_status;
  })
  .reset(getStateProviderStatusFx, failoverModalCloseEvent, clusterPageCloseEvent);

// effects
getFailoverFx.use(() => graphql.fetch(getFailoverParams));

changeFailoverFx.use((params) => graphql.fetch(changeFailoverMutation, params));

getStateProviderStatusFx.use(() => graphql.fetch(getStateProviderStatus));
