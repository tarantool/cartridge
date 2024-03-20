import { combine } from 'effector';

import { app } from 'src/models';

export type RebalancerStringValue = 'unset' | 'true' | 'false';

// events
export const rebalancerModalOpenEvent = app.domain.createEvent<{
  uuid: string;
  rebalancer?: boolean | null | undefined;
}>('rebalancer configure modal open event');
export const rebalancerModalCloseEvent = app.domain.createEvent('rebalancer configure modal close event');
export const changeRebalancerEvent = app.domain.createEvent<string>('change rebalancer event');
export const saveRebalancerEvent = app.domain.createEvent('save rebalancer event');

// stores
export const $selectedRebalancerUuid = app.domain.createStore<string | null>(null);
export const $selectedRebalancer = app.domain.createStore<RebalancerStringValue | null>(null);

// effects
export const editRebalancerFx = app.domain.createEffect<{ uuid: string; rebalancer: RebalancerStringValue }, void>(
  'edit rebalancer'
);

// computed
export const $rebalancerConfigureModal = combine({
  value: $selectedRebalancer,
  pending: editRebalancerFx.pending,
});
