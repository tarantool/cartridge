// @flow
import {
  createStore,
  createEvent,
  createStoreObject,
  sample,
  type Store
} from 'effector';
import {
  submitZoneFx,
  zoneAddModalClose,
  $error,
  $zoneAddForInstance,
  $zoneAddModalVisible
} from './index';

export const zoneInputChange = createEvent<string>();
export const addServerZone = createEvent<void>('submit click');

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

sample({
  source: createStoreObject({
    zone: $zoneName,
    uuid: $zoneAddForInstance
  }),
  clock: addServerZone,
  target: submitZoneFx
});
