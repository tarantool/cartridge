import { combine, forward, sample } from 'effector';

import { getErrorMessage } from 'src/api';
import { app } from 'src/models';

import { clusterPageClosedEvent } from '../page';
import { refreshServerListAndSetDirtyEvent } from '../server-list';
import {
  $zoneAddModalError,
  $zoneAddModalUuid,
  $zoneAddModalValue,
  addZoneFx,
  setServerZoneEvent,
  setZoneFailEvent,
  setZoneFx,
  zoneAddModalCloseEvent,
  zoneAddModalOpenEvent,
  zoneAddModalSubmitEvent,
} from '.';

const { notifyErrorEvent } = app;

sample({
  source: combine({
    uuid: $zoneAddModalUuid,
    zone: $zoneAddModalValue,
  }),
  clock: zoneAddModalSubmitEvent,
  target: addZoneFx,
});

forward({
  from: setServerZoneEvent,
  to: setZoneFx,
});

forward({
  from: [setZoneFx.done, addZoneFx.done],
  to: refreshServerListAndSetDirtyEvent,
});

forward({
  from: addZoneFx.done,
  to: zoneAddModalCloseEvent,
});

forward({
  from: setZoneFailEvent.map((error) => ({
    error,
    title: 'Zone change error',
  })),
  to: notifyErrorEvent,
});

// stores
$zoneAddModalValue.reset(zoneAddModalOpenEvent).reset(zoneAddModalCloseEvent).reset(clusterPageClosedEvent);

$zoneAddModalUuid
  .on(zoneAddModalOpenEvent, (_, { uuid }) => uuid)
  .reset(zoneAddModalCloseEvent)
  .reset(clusterPageClosedEvent);

$zoneAddModalError
  .on(addZoneFx.failData, (_, error) => getErrorMessage(error))
  .reset(addZoneFx)
  .reset(zoneAddModalCloseEvent)
  .reset(clusterPageClosedEvent);
