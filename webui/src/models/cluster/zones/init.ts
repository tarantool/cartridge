import { combine, forward, sample } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
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
const { passErrorMessageOnEvent, mapErrorWithTitle, passResultPathOnEvent } = app.utils;

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
  to: refreshServerListAndClusterEvent,
});

forward({
  from: addZoneFx.done,
  to: zoneAddModalCloseEvent,
});

forward({
  from: setZoneFailEvent.map(mapErrorWithTitle('Zone change error')),
  to: notifyErrorEvent,
});

// stores
$zoneAddModalValue.reset(zoneAddModalOpenEvent).reset(zoneAddModalCloseEvent).reset(clusterPageCloseEvent);

$zoneAddModalUuid
  .on(zoneAddModalOpenEvent, passResultPathOnEvent('uuid'))
  .reset(zoneAddModalCloseEvent)
  .reset(clusterPageCloseEvent);

$zoneAddModalError
  .on(addZoneFx.failData, passErrorMessageOnEvent)
  .reset(addZoneFx)
  .reset(zoneAddModalOpenEvent)
  .reset(zoneAddModalCloseEvent)
  .reset(clusterPageCloseEvent);

// effect
setZoneFx.use(async ({ uuid, zone }) => {
  if (!uuid) {
    throw new Error('Invalid server UUID');
  }

  await graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, zone: zone || '' }],
  });
});

addZoneFx.use(async ({ uuid, zone }) => {
  if (!uuid) {
    throw new Error('Invalid zone name');
  }

  await graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, zone: zone || '' }],
  });
});
