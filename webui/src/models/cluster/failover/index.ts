import { combine, restore } from 'effector';

import graphql from 'src/api/graphql';
import type {
  ChangeFailoverMutation,
  ChangeFailoverMutationVariables,
  GetFailoverParamsQuery,
} from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import { changeFailoverMutation, getFailoverParams } from 'src/store/request/queries.graphql';

import type { Failover } from './types';

// events
export const failoverModalOpenEvent = app.domain.createEvent('failover modal open event');
export const failoverModalCloseEvent = app.domain.createEvent('failover modal close event');

export const queryGetFailoverSuccessEvent = app.domain.createEvent<Failover>('query get failover success event');
export const changeFailoverEvent = app.domain.createEvent<ChangeFailoverMutationVariables>('change failover event');

// stores
export const $isFailoverModalOpen = app.domain.createStore(false);
export const $failover = restore(queryGetFailoverSuccessEvent, null);

// effects
export const getFailoverFx = app.domain.createEffect<void, GetFailoverParamsQuery>('get failover', {
  handler: () => graphql.fetch(getFailoverParams),
});

export const changeFailoverFx = app.domain.createEffect<ChangeFailoverMutationVariables, ChangeFailoverMutation>(
  'change failover',
  {
    handler: (params) => graphql.fetch(changeFailoverMutation, params),
  }
);

// computed
export const $failoverModal = combine({
  visible: $isFailoverModalOpen,
  loading: combine([getFailoverFx.pending]).map((state) => state.some(Boolean)),
  pending: combine([getFailoverFx.pending, changeFailoverFx.pending]).map((state) => state.some(Boolean)),
});
