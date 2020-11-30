// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  sample,
  type Effect,
  type Store
} from 'effector';
import { editServers } from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';
import { clusterPageMount } from './cluster';

export const zoneInputChange = createEvent<string>();
export const addServerZone = createEvent<void>('submit click');
export const zoneAddModalOpen = createEvent<string>('zone adding modal open');
export const zoneAddModalClose = createEvent<mixed>('zone adding modal close');

export const submitChangesFx: Effect<
  { uuid: string | null, zone: string },
  void,
  Error
> = createEffect(
  'submit server zone change',
  {
    handler: async ({ uuid, zone }) => {
      if (uuid && zone) await editServers([{ uuid, zone }]);
      else throw new Error('Invalid zone name or UUID');
    }
  }
);

export const $zoneName: Store<string> = createStore('')
  .on(zoneInputChange, (_, v: string) => v)
  .reset(submitChangesFx.done)
  .reset(zoneAddModalClose);

export const $zoneAddForInstance: Store<string | null> = createStore(null)
  .on(zoneAddModalOpen, (_, uuid) => uuid)
  .reset(submitChangesFx.done)
  .reset(zoneAddModalClose)
  .reset(clusterPageMount);

export const $zoneAddModalVisible = $zoneAddForInstance.map<boolean>(uuid => !!uuid);

export const $error: Store<?string> = createStore(null)
  .on(submitChangesFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitChangesFx)
  .reset(submitChangesFx.done)
  .reset(zoneAddModalClose)
  .reset(clusterPageMount);

export const $zoneAddModal = createStoreObject({
  visible: $zoneAddModalVisible,
  value: $zoneName,
  error: $error,
  pending: submitChangesFx.pending
})

sample({
  source: createStoreObject({
    zone: $zoneName,
    uuid: $zoneAddForInstance
  }),
  clock: addServerZone,
  target: submitChangesFx
});