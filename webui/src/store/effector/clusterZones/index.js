// @flow
import {
  createStore,
  createEvent,
  createEffect,
  guard,
  type Effect,
  type Store
} from 'effector';
import { editServers } from '../../request/clusterPage.requests';
import { getErrorMessage } from '../../../api';
import { clusterPageMount } from '../cluster';
import store from '../../instance';
import { CLUSTER_PAGE_ZONE_UPDATE } from '../../actionTypes';


export const zoneAddModalOpen = createEvent<string>('zone adding modal open');
export const zoneAddModalClose = createEvent<mixed>('zone adding modal close');

export const $zoneAddForInstance: Store<string | null> = createStore(null);
export const $error: Store<?string> = createStore(null);

export const setInstanceZoneFx: Effect<
  { uuid: string | null, zone?: string },
  void,
  Error
> = createEffect(
  'submit server zone change',
  {
    handler: async ({ uuid, zone }) => {
      if (uuid) await editServers([{ uuid, zone: zone || '' }]);
      else throw new Error('Invalid server UUID');
    }
  }
);

export const chooseZoneFail = guard<Error>({
  source: setInstanceZoneFx.failData,
  filter: $zoneAddForInstance.map(v => !v)
});

// init
$zoneAddForInstance
  .on(zoneAddModalOpen, (_, uuid) => uuid)
  .reset(zoneAddModalClose)
  .reset(clusterPageMount);

$error
  .on(setInstanceZoneFx.failData, (_, error) => getErrorMessage(error))
  .reset(setInstanceZoneFx)
  .reset(setInstanceZoneFx.done)
  .reset(clusterPageMount);

setInstanceZoneFx.done.watch(() => store.dispatch({ type: CLUSTER_PAGE_ZONE_UPDATE }));
