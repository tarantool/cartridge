import { forward } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { probeMutation } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $serverProbeModalError,
  $serverProbeModalVisible,
  serverProbeEvent,
  serverProbeFx,
  serverProbeModalCloseEvent,
  serverProbeModalOpenEvent,
} from '.';

const { notifySuccessEvent } = app;
const { trueL, passErrorMessageOnEvent } = app.utils;

forward({
  from: serverProbeEvent,
  to: serverProbeFx,
});

forward({
  from: serverProbeFx.done,
  to: [refreshServerListAndClusterEvent, serverProbeModalCloseEvent],
});

forward({
  from: serverProbeFx.done.map(() => 'Probe is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

// stores
$serverProbeModalVisible
  .on(serverProbeModalOpenEvent, trueL)
  .reset(serverProbeModalCloseEvent)
  .reset(clusterPageCloseEvent);

$serverProbeModalError
  .on(serverProbeFx.failData, passErrorMessageOnEvent)
  .reset(serverProbeFx)
  .reset(serverProbeModalOpenEvent)
  .reset(serverProbeModalCloseEvent)
  .reset(clusterPageCloseEvent);

// effects
serverProbeFx.use(({ uri }) => graphql.mutate(probeMutation, { uri }));
