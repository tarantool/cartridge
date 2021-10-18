import { forward } from 'effector';

import { getErrorMessage } from 'src/api';
import { app } from 'src/models';

import { clusterPageClosedEvent } from '../page';
import { refreshServerListAndSetDirtyEvent } from '../server-list';
import {
  $isServerProveModalOpen,
  $serverProbeModalError,
  serverProbeEvent,
  serverProbeFx,
  serverProbeModalCloseEvent,
  serverProbeModalOpenEvent,
} from '.';

const { notifySuccessEvent } = app;
const { trueL } = app.utils;

forward({
  from: serverProbeEvent,
  to: serverProbeFx,
});

forward({
  from: serverProbeFx.done,
  to: [refreshServerListAndSetDirtyEvent, serverProbeModalCloseEvent],
});

forward({
  from: serverProbeFx.done.map(() => 'Probe is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

// stores
$isServerProveModalOpen
  .on(serverProbeModalOpenEvent, trueL)
  .reset(serverProbeModalCloseEvent)
  .reset(clusterPageClosedEvent);

$serverProbeModalError
  .on(serverProbeFx.failData, (_, error) => getErrorMessage(error))
  .reset(serverProbeFx)
  .reset(serverProbeModalCloseEvent)
  .reset(clusterPageClosedEvent);
