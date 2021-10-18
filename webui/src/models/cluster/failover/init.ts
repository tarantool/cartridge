import { forward, guard } from 'effector';

import { app } from 'src/models';

import { clusterPageClosedEvent } from '../page';
import { refreshClusterEvent } from '../server-list';
import {
  $failover,
  $isFailoverModalOpen,
  changeFailoverEvent,
  changeFailoverFx,
  failoverModalCloseEvent,
  failoverModalOpenEvent,
  getFailoverFx,
  queryGetFailoverSuccessEvent,
} from '.';

const { notifyErrorEvent } = app;
const { trueL } = app.utils;

forward({
  from: failoverModalOpenEvent,
  to: getFailoverFx,
});

forward({
  from: changeFailoverEvent,
  to: changeFailoverFx,
});

guard({
  source: getFailoverFx.doneData,
  filter: $isFailoverModalOpen,
  target: queryGetFailoverSuccessEvent,
});

forward({
  from: changeFailoverFx.done,
  to: [refreshClusterEvent, failoverModalCloseEvent],
});

forward({
  from: changeFailoverFx.failData,
  to: notifyErrorEvent,
});

// stores
$failover.reset(failoverModalCloseEvent).reset(clusterPageClosedEvent);

$isFailoverModalOpen.on(failoverModalOpenEvent, trueL).reset(failoverModalCloseEvent).reset(clusterPageClosedEvent);
