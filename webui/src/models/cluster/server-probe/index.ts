import { combine } from 'effector';

import { app } from 'src/models';

// events
export const serverProbeModalOpenEvent = app.domain.createEvent('server probe modal open event');
export const serverProbeModalCloseEvent = app.domain.createEvent('server probe modal close event');
export const serverProbeEvent = app.domain.createEvent<{ uri: string }>('server probe event');

// stores
export const $serverProbeModalVisible = app.domain.createStore(false);
export const $serverProbeModalError = app.domain.createStore<string | null>(null);

// effects
export const serverProbeFx = app.domain.createEffect<{ uri: string }, void>('expel server');

// computed
export const $serverProbeModal = combine({
  visible: $serverProbeModalVisible,
  error: $serverProbeModalError,
  pending: serverProbeFx.pending,
});
