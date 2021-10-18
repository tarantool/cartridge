import { forward, guard } from 'effector';

import { app } from 'src/models';

import { $isClusterPageOpen, clusterPageClosedEvent, clusterPageOpenedEvent } from '../page';
import { disableOrEnableServerFx, promoteServerToLeaderFx, queryClusterFx, queryServerListFx } from './effects';
import {
  $cluster,
  $serverList,
  $serverListIsDirty,
  disableOrEnableServerEvent,
  promoteServerToLeaderEvent,
  queryClusterSuccessEvent,
  queryServerListSuccessEvent,
  refreshClusterEvent,
  refreshServerListAndSetDirtyEvent,
  refreshServerListEvent,
  setServerListIsDirtyEvent,
} from '.';

const { notifyErrorEvent } = app;
const { createTimeoutFx, voidL, falseL, trueL, combineResultOnEvent, passResultOnEvent } = app.utils;

const mapWithStat = () => ({ withStats: true });

forward({
  from: clusterPageOpenedEvent,
  to: queryClusterFx,
});

forward({
  from: promoteServerToLeaderEvent,
  to: promoteServerToLeaderFx,
});

forward({
  from: disableOrEnableServerEvent,
  to: disableOrEnableServerFx,
});

forward({
  from: refreshServerListEvent.map(mapWithStat),
  to: queryServerListFx,
});

forward({
  from: refreshClusterEvent,
  to: queryClusterFx,
});

forward({
  from: refreshServerListAndSetDirtyEvent.map(mapWithStat),
  to: queryServerListFx,
});

guard({
  source: queryServerListFx.doneData,
  filter: $isClusterPageOpen,
  target: queryServerListSuccessEvent,
});

guard({
  source: queryClusterFx.doneData,
  filter: $isClusterPageOpen,
  target: queryClusterSuccessEvent,
});

// notifications
forward({
  from: promoteServerToLeaderFx.done.map(() => ({
    title: 'Failover',
    message: 'Leader promotion successful',
  })),
  to: app.notifyEvent,
});

forward({
  from: promoteServerToLeaderFx.failData.map((error) => ({
    error,
    title: 'Leader promotion error',
  })),
  to: notifyErrorEvent,
});

forward({
  from: disableOrEnableServerFx.failData.map((error) => ({
    error,
    title: 'Disabled state setting error',
  })),
  to: notifyErrorEvent,
});

createTimeoutFx('ServerListTimeoutFx', {
  startEvent: clusterPageOpenedEvent,
  stopEvent: clusterPageClosedEvent,
  timeout: (): number => app.variables.cartridge_refresh_interval(),
  effect: (counter: number): Promise<void> =>
    queryServerListFx({
      withStats: counter % app.variables.cartridge_stat_period() === 0,
    }).then(voidL),
});

// stores
$serverList.on(queryServerListSuccessEvent, combineResultOnEvent).reset(clusterPageClosedEvent);

$serverListIsDirty
  .on(setServerListIsDirtyEvent, trueL)
  .on(refreshServerListAndSetDirtyEvent, trueL)
  .on(queryServerListSuccessEvent, falseL)
  .reset(clusterPageClosedEvent);

$cluster.on(queryClusterSuccessEvent, passResultOnEvent).reset(clusterPageClosedEvent);
