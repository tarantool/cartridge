import { forward, guard } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import { refreshServerListAndClusterEvent } from '../server-list';
import {
  $selectedServerExpelModalServer,
  $selectedServerExpelModalUri,
  serverExpelEvent,
  serverExpelFx,
  serverExpelModalCloseEvent,
  serverExpelModalOpenEvent,
} from '.';

const { notifyErrorEvent, notifySuccessEvent } = app;
const { passResultPathOnEvent } = app.utils;

guard({
  source: $selectedServerExpelModalServer,
  clock: serverExpelEvent,
  filter: Boolean,
  target: serverExpelFx,
});

forward({
  from: serverExpelFx.done,
  to: refreshServerListAndClusterEvent,
});

forward({
  from: serverExpelFx.finally,
  to: serverExpelModalCloseEvent,
});

forward({
  from: serverExpelFx.done.map(() => 'Expel is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: serverExpelFx.failData.map((error) => ({
    error,
    title: 'Server expel error',
  })),
  to: notifyErrorEvent,
});

// stores
$selectedServerExpelModalUri
  .on(serverExpelModalOpenEvent, passResultPathOnEvent('uri'))
  .reset(serverExpelModalCloseEvent)
  .reset(clusterPageCloseEvent);

// effects
serverExpelFx.use(async (props) => {
  if (props?.uuid) {
    await graphql.mutate(editTopologyMutation, {
      servers: [{ uuid: props.uuid, expelled: true }],
    });
  }
});
