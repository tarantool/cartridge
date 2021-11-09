import { combine, sample } from 'effector';

import { Maybe, app } from 'src/models';

import { $serverList, selectors } from '../server-list';

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
export const serverExpelFx = app.domain.createEffect<Maybe<{ uuid?: string }>, void>('expel server');

// computed
export const $serverExpelModal = combine({
  value: $selectedServerExpelModalServer,
  visible: $selectedServerExpelModalServer.map(Boolean),
  pending: serverExpelFx.pending,
});
