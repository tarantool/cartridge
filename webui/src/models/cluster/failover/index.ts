import { combine } from 'effector';

import type {
  ChangeFailoverMutation,
  ChangeFailoverMutationVariables,
  GetFailoverParamsQuery,
} from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import type { Failover, StateProviderStatus } from './types';

const { some } = app.utils;

// events
export const failoverModalOpenEvent = app.domain.createEvent('failover modal open event');
export const failoverModalCloseEvent = app.domain.createEvent('failover modal close event');
export const stateProviderStatusGetEvent = app.domain.createEvent('state provider status popover open event');

export const changeFailoverEvent = app.domain.createEvent<ChangeFailoverMutationVariables>('change failover event');

// stores
export const $failoverModalVisible = app.domain.createStore(false);
export const $failoverModalError = app.domain.createStore<string>('');
export const $failover = app.domain.createStore<Failover>(null);
export const $stateProviderStatus = app.domain.createStore<StateProviderStatus[]>([]);

// effects
export const getFailoverFx = app.domain.createEffect<void, GetFailoverParamsQuery>('get failover');
export const changeFailoverFx = app.domain.createEffect<ChangeFailoverMutationVariables, ChangeFailoverMutation>(
  'change failover'
);
export const getStateProviderStatusFx = app.domain.createEffect<
  void,
  { cluster: { failover_state_provider_status: StateProviderStatus[] } }
>('get state provider status');

// computed
export const $failoverModal = combine({
  visible: $failoverModalVisible,
  error: $failoverModalError,
  loading: getFailoverFx.pending,
  pending: combine([getFailoverFx.pending, changeFailoverFx.pending]).map(some),
});
