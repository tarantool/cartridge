import { combine } from 'effector';

import { app } from 'src/models';

export type RebalancerStringValue = 'unset' | 'true' | 'false';

// events
export const rebalancerModeModalOpenEvent = app.domain.createEvent<{
  name: string;
  rebalancer_mode: string;
}>('rebalancer mode configure modal open event');
export const rebalancerModeModalCloseEvent = app.domain.createEvent('rebalancer mode configure modal close event');
export const changeRebalancerModeEvent = app.domain.createEvent<string>('change rebalancer mode event');
export const saveRebalancerModeEvent = app.domain.createEvent('save rebalancer mode event');

// stores
export const $selectedRebalancerName = app.domain.createStore<string | null>(null);
export const $selectedRebalancerMode = app.domain.createStore<string | null>(null);

// effects
export const editRebalancerModeFx = app.domain.createEffect<{ name: string; rebalancer_mode: string }, void>(
  'edit rebalancer mode'
);

// computed
export const $rebalancerModeConfigureModal = combine({
  value: $selectedRebalancerMode,
  pending: editRebalancerModeFx.pending,
});
