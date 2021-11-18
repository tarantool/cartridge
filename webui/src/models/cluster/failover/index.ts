import { combine } from 'effector';

import type {
  ChangeFailoverMutation,
  ChangeFailoverMutationVariables,
  GetFailoverParamsQuery,
} from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import type { Failover } from './types';

const { some } = app.utils;

// events
export const failoverModalOpenEvent = app.domain.createEvent('failover modal open event');
export const failoverModalCloseEvent = app.domain.createEvent('failover modal close event');

export const changeFailoverEvent = app.domain.createEvent<ChangeFailoverMutationVariables>('change failover event');

// stores
export const $failoverModalVisible = app.domain.createStore(false);
export const $failoverModalError = app.domain.createStore<string>('');
export const $failover = app.domain.createStore<Failover>(null);

// effects
export const getFailoverFx = app.domain.createEffect<void, GetFailoverParamsQuery>('get failover');
export const changeFailoverFx = app.domain.createEffect<ChangeFailoverMutationVariables, ChangeFailoverMutation>(
  'change failover'
);

// computed
export const $failoverModal = combine({
  visible: $failoverModalVisible,
  error: $failoverModalError,
  loading: getFailoverFx.pending,
  pending: combine([getFailoverFx.pending, changeFailoverFx.pending]).map(some),
});
