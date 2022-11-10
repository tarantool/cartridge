import { sample } from 'effector';

import graphql from 'src/api/graphql';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { $serverList, selectors } from '../server-list';
import {
  $labelsServer,
  $requestAddedLabels,
  $selectedServerUuid,
  $serverAddLabelModalVisible,
  addLabelEvent,
  editServerEvent,
  editServerFx,
  removeLabelEvent,
  serverAddLabelModalCloseEvent,
  serverAddLabelModalOpenEvent,
  updateLabelEvent,
} from '.';

sample({
  clock: $selectedServerUuid,
  source: $serverList,
  fn: (source, clock) => {
    return selectors.serverLabelsGetByUuid(source, clock as string);
  },
  target: updateLabelEvent,
});

sample({
  clock: editServerEvent,
  source: $requestAddedLabels,
  fn: ({ uuid, labels }) => ({ uuid: uuid as string, labels }),
  target: editServerFx,
});

editServerFx.use(({ labels, uuid }) => {
  return graphql.fetch(editTopologyMutation, {
    servers: [
      {
        uuid,
        labels,
      },
    ],
  });
});

$selectedServerUuid.on(serverAddLabelModalOpenEvent, (_, { uuid }) => uuid).reset(serverAddLabelModalCloseEvent);
$labelsServer
  .on(addLabelEvent, (store, payload) => [...store, payload])
  .on(updateLabelEvent, (_, payload) => payload)
  .on(removeLabelEvent, (state, payload) => state.filter((label) => label.name !== payload))
  .reset(serverAddLabelModalCloseEvent);

$serverAddLabelModalVisible.on(serverAddLabelModalOpenEvent, () => true).on(serverAddLabelModalCloseEvent, () => false);
