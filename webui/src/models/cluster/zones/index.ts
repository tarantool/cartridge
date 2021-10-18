import { combine, guard, restore } from 'effector';

import graphql from 'src/api/graphql';
import { Maybe, app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { $serverListIsDirty } from '../server-list';

const { not } = app.utils;

// events
export const setServerZoneEvent = app.domain.createEvent<{ uuid: string; zone?: string }>('set server sone click');
export const zoneAddModalOpenEvent = app.domain.createEvent<{ uuid: string }>('zone adding modal open');
export const zoneAddModalCloseEvent = app.domain.createEvent('zone adding modal close');
export const zoneAddModalSetValueEvent = app.domain.createEvent<string>('zone adding modal set value');
export const zoneAddModalSubmitEvent = app.domain.createEvent('add server zone modal submit');

// stores
export const $zoneAddModalError = app.domain.createStore<Error | null>(null);
export const $zoneAddModalValue = restore(zoneAddModalSetValueEvent, '');
export const $zoneAddModalUuid = app.domain.createStore<string | null>(null);

// effect
export const setZoneFx = app.domain.createEffect<{ uuid?: Maybe<string>; zone?: Maybe<string> }, void, Error>(
  'set server zone',
  {
    handler: async ({ uuid, zone }) => {
      if (!uuid) {
        throw new Error('Invalid server UUID');
      }

      await graphql.mutate(editTopologyMutation, {
        servers: [{ uuid, zone: zone || '' }],
      });
    },
  }
);

export const addZoneFx = app.domain.createEffect<{ uuid?: Maybe<string>; zone?: Maybe<string> }, void, Error>(
  'add server zone',
  {
    handler: async ({ uuid, zone }) => {
      if (!uuid) {
        throw new Error('Invalid zone name');
      }

      await graphql.mutate(editTopologyMutation, {
        servers: [{ uuid, zone: zone || '' }],
      });
    },
  }
);

// computed
export const setZoneFailEvent = guard<Error>({
  source: setZoneFx.failData,
  filter: $zoneAddModalUuid.map(not),
});

export const $zoneAddModal = combine({
  value: $zoneAddModalValue,
  visible: $zoneAddModalUuid.map(Boolean),
  pending: combine([setZoneFx.pending, addZoneFx.pending, $serverListIsDirty]).map((state) => state.some(Boolean)),
  error: $zoneAddModalError.map((error) => error?.message),
});
