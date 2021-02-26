// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  sample,
  combine
} from 'effector';
import type { Effect, Store } from 'effector';
import { equals } from 'ramda';
import { disableServers, editServers } from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';
import {
  clusterPageMount,
  statsResponseSuccess,
  statsResponseError,
  type ClusterRefineURISuggestion,
  type ClusterDisableServersSuggestion
} from './cluster';
import type { EditServerInput } from 'src/generated/graphql-typing';

export const advertiseURIApplyClick = createEvent<mixed>('advertise URI apply click');
export const advertiseURIDetailsClick = createEvent<mixed>('advertise URI details click');
export const disableServersApplyClick = createEvent<mixed>('disable servers apply click');
export const disableServersDetailsClick = createEvent<mixed>('disable servers details click');
export const detailsClose = createEvent<mixed>('details modal close');

const submitAdvertiseURIFx: Effect<
  Array<EditServerInput>,
  void,
  Error
> = createEffect(
  'submit servers uri changes',
  { handler: servers => editServers(servers) }
);

const submitDisableServersFx: Effect<
  Array<string>,
  void,
  Error
> = createEffect(
  'submit disable servers',
  { handler: uuids => disableServers(uuids) }
);

export const $advertiseURISuggestion: Store<?ClusterRefineURISuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.refine_uri) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

export const $disableServersSuggestion: Store<?ClusterDisableServersSuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.disable_servers) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

export const $panelsVisibility: Store<{ advertiseURI: bool, disableServers: bool }> = combine(
  {
    advertiseURI: $advertiseURISuggestion,
    disableServers: $disableServersSuggestion
  },
  ({ advertiseURI, disableServers }) => ({
    advertiseURI: !!advertiseURI,
    disableServers: !!(disableServers && disableServers.length)
  })
);

export const $advertiseURIModalVisible: Store<bool> = createStore(false)
  .on(advertiseURIDetailsClick, () => true)
  .reset(submitAdvertiseURIFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $disableServerModalVisible: Store<bool> = createStore(false)
  .on(disableServersDetailsClick, () => true)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $advertiseURIError: Store<?string> = createStore(null)
  .on(submitAdvertiseURIFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitAdvertiseURIFx)
  .reset(submitAdvertiseURIFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $disableServersError: Store<?string> = createStore(null)
  .on(submitDisableServersFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitDisableServersFx)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

export const $advertiseURIModal = createStoreObject({
  visible: $advertiseURIModalVisible,
  suggestions: $advertiseURISuggestion,
  error: $advertiseURIError,
  pending: submitAdvertiseURIFx.pending
})

export const $disableServersModal = createStoreObject({
  visible: $disableServerModalVisible,
  suggestions: $disableServersSuggestion,
  error: $disableServersError,
  pending: submitDisableServersFx.pending
})

sample({
  source: $advertiseURISuggestion,
  clock: advertiseURIApplyClick,
  fn: servers => (servers || []).map(({ uuid, uri_new: uri }) => ({ uuid, uri })),
  target: submitAdvertiseURIFx
});

sample({
  source: $disableServersSuggestion,
  clock: disableServersApplyClick,
  fn: servers => (servers || []).map(({ uuid }) => uuid),
  target: submitDisableServersFx
});
