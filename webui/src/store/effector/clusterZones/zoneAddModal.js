// @flow
import {
  createStore,
  createEffect,
  createEvent,
  createStoreObject,
  sample,
  type Effect,
  type Store
} from 'effector';
import { editServers } from '../../request/clusterPage.requests';
import { getErrorMessage } from '../../../api';
import {
  zoneAddModalClose,
  $zoneAddForInstance
} from './index';
import store from '../../instance';
import { CLUSTER_PAGE_ZONE_UPDATE } from '../../actionTypes';

export const zoneInputChange = createEvent<string>();
export const addServerZone = createEvent<void>('submit click');

export const $zoneAddModalVisible = $zoneAddForInstance.map<boolean>(uuid => !!uuid);
export const $error: Store<?string> = createStore(null);

export const submitZoneFx: Effect<
  { uuid: string | null, zone: string },
  void,
  Error
> = createEffect(
  'submit server zone change',
  {
    handler: async ({ uuid, zone }) => {
      if (uuid && zone) await editServers([{ uuid, zone }]);
      else throw new Error('Invalid zone name');
    }
  }
);

export const $zoneName: Store<string> = createStore('')
  .on(zoneInputChange, (_, v: string) => v)
  .reset(submitZoneFx.done)
  .reset(zoneAddModalClose);

export const $zoneAddModal = createStoreObject({
  visible: $zoneAddModalVisible,
  value: $zoneName,
  error: $error,
  pending: submitZoneFx.pending
})

$error
  .on(submitZoneFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitZoneFx)
  .reset(submitZoneFx.done)
  .reset(zoneAddModalClose);

sample({
  source: createStoreObject({
    zone: $zoneName,
    uuid: $zoneAddForInstance
  }),
  clock: addServerZone,
  target: submitZoneFx
});

$zoneAddForInstance
  .reset(submitZoneFx.done);

submitZoneFx.done.watch(() => store.dispatch({ type: CLUSTER_PAGE_ZONE_UPDATE }));
