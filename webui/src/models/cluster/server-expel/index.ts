import { combine, sample } from 'effector';

import graphql from 'src/api/graphql';
import { Maybe, app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { $serverList, $serverListIsDirty, selectors } from '../server-list';

// events
export const serverExpelModalOpenEvent = app.domain.createEvent<{ uri: string }>('expel server modal open event');
export const serverExpelModalCloseEvent = app.domain.createEvent('expel server modal close event');
export const serverExpelEvent = app.domain.createEvent('expel server event');

// stores
export const $selectedServerExpelModalUri = app.domain.createStore<string | null>(null);
export const $selectedServerExpelModalServer = sample({
  source: [$serverList, $selectedServerExpelModalUri],
  fn: ([serverList, uri]) => selectors.serverGetByUri(serverList, uri) ?? null,
});

// effects
export const serverExpelFx = app.domain.createEffect<Maybe<{ uuid?: string }>, void>('expel server', {
  handler: async (props) => {
    if (props?.uuid) {
      await graphql.mutate(editTopologyMutation, {
        servers: [{ uuid: props.uuid, expelled: true }],
      });
    }
  },
});

// computed
export const $serverExpelModal = combine({
  value: $selectedServerExpelModalServer,
  visible: $selectedServerExpelModalServer.map(Boolean),
  pending: combine([serverExpelFx.pending, $serverListIsDirty]).map((state) => state.some(Boolean)),
});
