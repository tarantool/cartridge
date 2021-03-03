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
import {
  disableServers,
  editServers,
  configForceReapply
} from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';
import {
  clusterPageMount,
  statsResponseSuccess,
  statsResponseError
} from './cluster';
import type {
  DisableServerSuggestion,
  EditServerInput,
  ForceApplySuggestion,
  RefineUriSuggestion
} from 'src/generated/graphql-typing';

export const advertiseURIApplyClick = createEvent<mixed>('advertise URI apply click');
export const advertiseURIDetailsClick = createEvent<mixed>('advertise URI details click');
export const disableServersApplyClick = createEvent<mixed>('disable servers apply click');
export const disableServersDetailsClick = createEvent<mixed>('disable servers details click');
export const forceApplyConfApplyClick = createEvent<mixed>('force apply config apply click');
export const forceApplyConfDetailsClick = createEvent<mixed>('force apply config details click');
export const forceApplyInstanceCheck = createEvent<string>('force apply check instance');
export const forceApplyReasonCheck = createEvent<string>('force apply check instances with same reason');
export const forceApplyReasonUncheck = createEvent<string>('force apply uncheck instances with same reason');
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

const submitForceApplyFx: Effect<
  Array<string>,
  void,
  Error
> = createEffect(
  'submit disable servers',
  { handler: uuids => configForceReapply(uuids) }
);

const $advertiseURISuggestion: Store<?RefineUriSuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.refine_uri) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

const $disableServersSuggestion: Store<?DisableServerSuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.disable_servers) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

const $forceApplySuggestion: Store<?ForceApplySuggestion[]> = createStore(null)
  .on(
    statsResponseSuccess,
    (prev, { suggestions }) => {
      const next = (suggestions && suggestions.force_apply) || null;
      return equals(prev, next) ? prev : next;
    }
  )
  .reset(statsResponseError)
  .reset(clusterPageMount);

type ForceApplySuggestionByReason = [
  ['operation_error', string[]],
  ['config_locked', string[]],
  ['config_mismatch', string[]]
]

const $forceApplySuggestionByReason: Store<ForceApplySuggestionByReason> = $forceApplySuggestion.map(state => {
  const r = { operation_error: [], config_locked: [], config_mismatch: [] };
  state && state.forEach(
    ({ uuid, ...rest }) => Object.entries(rest)
      .map(([k, v]) => (v && r[k].push(uuid)))
  );
  return ((Object.entries(r): any): ForceApplySuggestionByReason);
});

type CheckedServers = {[key: string]: boolean};

const $forceApplyModalCheckedServers: Store<CheckedServers> = createStore({})
  .on(
    $forceApplySuggestion,
    (prevState, state) => (state || []).reduce(
      (acc, { uuid }) => {
        acc[uuid] = (prevState && uuid in prevState) ? prevState[uuid] : true;
        return acc;
      },
      {}
    )
  )
  .on(forceApplyInstanceCheck, (state, uuid) => ({ ...state, [uuid]: !state[uuid] }));

type PanelsVisibility = {
  advertiseURI: bool,
  disableServers: bool,
  forceApply: bool
};

export const $panelsVisibility: Store<PanelsVisibility> = combine(
  {
    advertiseURI: $advertiseURISuggestion,
    disableServers: $disableServersSuggestion,
    forceApply: $forceApplySuggestion
  },
  ({ advertiseURI, disableServers, forceApply }) => ({
    advertiseURI: !!advertiseURI,
    disableServers: !!(disableServers && disableServers.length),
    forceApply: !!(forceApply && forceApply.length)
  })
);

const $advertiseURIModalVisible: Store<bool> = createStore(false)
  .on(advertiseURIDetailsClick, () => true)
  .reset(submitAdvertiseURIFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

const $disableServerModalVisible: Store<bool> = createStore(false)
  .on(disableServersDetailsClick, () => true)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

const $forceApplyModalVisible: Store<bool> = createStore(false)
  .on(forceApplyConfDetailsClick, () => true)
  .reset(submitForceApplyFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

const $advertiseURIError: Store<?string> = createStore(null)
  .on(submitAdvertiseURIFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitAdvertiseURIFx)
  .reset(submitAdvertiseURIFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

const $disableServersError: Store<?string> = createStore(null)
  .on(submitDisableServersFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitDisableServersFx)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageMount);

const $forceApplyError: Store<?string> = createStore(null)
  .on(submitForceApplyFx.failData, (_, error) => getErrorMessage(error))
  .reset(submitForceApplyFx)
  .reset(submitForceApplyFx.done)
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

export const $forceApplyModal = createStoreObject({
  visible: $forceApplyModalVisible,
  suggestions: $forceApplySuggestionByReason,
  error: $forceApplyError,
  pending: submitForceApplyFx.pending,
  checked: $forceApplyModalCheckedServers
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

sample({
  source: $forceApplyModalCheckedServers,
  clock: forceApplyConfApplyClick,
  fn: uuids => Object.entries(uuids)
    .filter(([uuid, checked]) => checked)
    .map(([uuid]) => uuid),
  target: submitForceApplyFx
});

const createCheckAllFn = (check: boolean) => (
  { suggestions, checked }: {
    suggestions: ForceApplySuggestionByReason,
    checked: CheckedServers
  },
  reason: string
): CheckedServers => {
  const r = { ...checked };
  const uuids = (suggestions.find(([r]) => reason === r) || [null, {}])[1];
  uuids.forEach(uuid => r[uuid] = check);
  return r;
}

sample({
  source: $forceApplyModal,
  clock: forceApplyReasonCheck,
  fn: createCheckAllFn(true),
  target: $forceApplyModalCheckedServers
});

sample({
  source: $forceApplyModal,
  clock: forceApplyReasonUncheck,
  fn: createCheckAllFn(false),
  target: $forceApplyModalCheckedServers
});
