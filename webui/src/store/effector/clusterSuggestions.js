// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  sample
} from 'effector';
import type { Effect, Store } from 'effector';
import { equals } from 'ramda';
import { editServers } from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';
import {
  clusterPageMount,
  statsResponseSuccess,
  statsResponseError,
  type ClusterRefineURISuggestion
} from './cluster';
import type { EditServerInput } from 'src/generated/graphql-typing';

export const applyClick = createEvent<any>('apply click');
export const detailsClick = createEvent<any>('details modal click');
export const detailsClose = createEvent<any>('details modal close');

export const submitChangesFx: Effect<
  Array<EditServerInput>,
  void,
  Error
> = createEffect(
  'submit servers uri changes',
  { handler: servers => editServers(servers) }
);

export const $advertiseURISuggestions: Store<?ClusterRefineURISuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.refine_uri) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

export const $advertisePanelVisible: Store<bool> = $advertiseURISuggestions.map(
  refine_uri => !!refine_uri
);

export const $advertiseModalVisible: Store<bool> = createStore(false)
  .on(detailsClick, () => true)
  .reset(submitChangesFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $error: Store<?string> = createStore(null)
  .on(submitChangesFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitChangesFx)
  .reset(submitChangesFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $advertiseModal = createStoreObject({
  visible: $advertiseModalVisible,
  suggestions: $advertiseURISuggestions,
  error: $error,
  pending: submitChangesFx.pending
})

sample({
  source: $advertiseURISuggestions,
  clock: applyClick,
  fn: servers => (servers || []).map(({ uuid, uri_new: uri }) => ({ uuid, uri })),
  target: submitChangesFx
});