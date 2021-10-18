import { combine } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { probeMutation } from 'src/store/request/queries.graphql';

import { $serverListIsDirty } from '../server-list';

// events
export const serverProbeModalOpenEvent = app.domain.createEvent('server probe modal open event');
export const serverProbeModalCloseEvent = app.domain.createEvent('server probe modal close event');
export const serverProbeEvent = app.domain.createEvent<{ uri: string }>('server probe event');

// stores
export const $serverProbeModalError = app.domain.createStore<string | null>(null);
export const $isServerProveModalOpen = app.domain.createStore(false);

// effects
export const serverProbeFx = app.domain.createEffect<{ uri: string }, void>('expel server', {
  handler: ({ uri }) =>
    graphql.mutate(probeMutation, {
      uri,
    }),
});

// computed
export const $serverProbeModal = combine({
  visible: $isServerProveModalOpen,
  error: $serverProbeModalError,
  pending: combine([serverProbeFx.pending, $serverListIsDirty]).map((state) => state.some(Boolean)),
});
