import { combine, guard } from 'effector';

import { Maybe, app } from 'src/models';

const { not, some } = app.utils;

// events
export const setServerZoneEvent = app.domain.createEvent<{ uuid: string; zone?: string }>('set server sone click');
export const zoneAddModalOpenEvent = app.domain.createEvent<{ uuid: string }>('zone adding modal open');
export const zoneAddModalCloseEvent = app.domain.createEvent('zone adding modal close');
export const zoneAddModalSetValueEvent = app.domain.createEvent<string>('zone adding modal set value');
export const zoneAddModalSubmitEvent = app.domain.createEvent('add server zone modal submit');

// stores
export const $zoneAddModalError = app.domain.createStore<string>('');
export const $zoneAddModalValue = app.domain.createStore<string>('');
export const $zoneAddModalUuid = app.domain.createStore<string | null>(null);

// effect
export const setZoneFx = app.domain.createEffect<{ uuid?: Maybe<string>; zone?: Maybe<string> }, void, Error>(
  'set server zone'
);

export const addZoneFx = app.domain.createEffect<{ uuid?: Maybe<string>; zone?: Maybe<string> }, void, Error>(
  'add server zone'
);

// computed
export const setZoneFailEvent = guard<Error>({
  source: setZoneFx.failData,
  filter: $zoneAddModalUuid.map(not),
});

export const $zoneAddModal = combine({
  value: $zoneAddModalValue,
  visible: $zoneAddModalUuid.map(Boolean),
  pending: combine([setZoneFx.pending, addZoneFx.pending]).map(some),
  error: $zoneAddModalError,
});
