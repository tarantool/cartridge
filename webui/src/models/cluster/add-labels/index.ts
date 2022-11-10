import { combine } from 'effector';

import { EditServerInput, EditTopologyMutation, LabelInput } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

//events
export const serverAddLabelModalOpenEvent = app.domain.createEvent<{ uuid: string }>(
  'add label server modal open event'
);
export const serverAddLabelModalCloseEvent = app.domain.createEvent('add label server modal close event');
export const editServerEvent = app.domain.createEvent('edit server event');
export const addLabelEvent = app.domain.createEvent<LabelInput>('add labels event');
export const removeLabelEvent = app.domain.createEvent<string>('remove server event');
export const updateLabelEvent = app.domain.createEvent<LabelInput[]>('remove server event');

//stores
export const $serverAddLabelModalVisible = app.domain.createStore(false);
export const $selectedServerUuid = app.domain.createStore<string | null>(null);
export const $labelsServer = app.domain.createStore<LabelInput[]>([]);
export const $requestAddedLabels = combine({
  uuid: $selectedServerUuid,
  labels: $labelsServer,
});

// effects
export const editServerFx = app.domain.createEffect<EditServerInput, EditTopologyMutation>('edit server');

//computed
export const $serverLabels = combine({
  labels: $labelsServer,
  visible: $serverAddLabelModalVisible,
});
