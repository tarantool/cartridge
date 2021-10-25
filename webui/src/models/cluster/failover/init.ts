import { forward } from 'effector';

import { app } from 'src/models';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $failover,
  $failoverModalError,
  $failoverModalVisible,
  changeFailoverEvent,
  changeFailoverFx,
  failoverModalCloseEvent,
  failoverModalOpenEvent,
  getFailoverFx,
} from '.';

const { notifyEvent, notifyErrorEvent } = app;
const { trueL, passResultOnEvent, passErrorMessageOnEvent } = app.utils;

forward({
  from: failoverModalOpenEvent,
  to: getFailoverFx,
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
  from: changeFailoverFx.failData,
  to: notifyErrorEvent,
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
