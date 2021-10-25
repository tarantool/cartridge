import { combine } from 'effector';

import type { GetClusterQuery, ServerListQuery } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import { requestBootstrapFx } from './effects';
import * as filters from './filters';
import * as selectors from './selectors';
import type {
  DisableOrEnableServerEventPayload,
  GetCluster,
  PromoteServerToLeaderEventPayload,
  ServerList,
} from './types';

// exports
export { selectors, filters };

// events
export const queryServerListSuccessEvent = app.domain.createEvent<ServerListQuery>('query server list success event');
export const queryServerListErrorEvent = app.domain.createEvent<Error>('query server list error event');
export const queryClusterSuccessEvent = app.domain.createEvent<GetClusterQuery>('query cluster success event');
export const queryClusterErrorEvent = app.domain.createEvent<Error>('query cluster error event');

export const refreshServerListAndClusterEvent = app.domain.createEvent('refresh server list and cluster event');

export const promoteServerToLeaderEvent = app.domain.createEvent<PromoteServerToLeaderEventPayload>(
  'promote server to leader event'
);

export const disableOrEnableServerEvent = app.domain.createEvent<DisableOrEnableServerEventPayload>(
  'disable or enable server event'
);

export const requestBootstrapEvent = app.domain.createEvent('request bootstrap event');
export const showBootstrapPanelEvent = app.domain.createEvent('show bootstrap panel event');
export const hideBootstrapPanelEvent = app.domain.createEvent('hide bootstrap panel event');

// stores
export const $serverList = app.domain.createStore<ServerList>(null);
export const $cluster = app.domain.createStore<GetCluster>(null);

export const $bootstrapPanelVisible = app.domain.createStore(false);

// computed
export const $failoverParamsMode = $cluster.map((state) => selectors.failoverParamsMode(state) ?? null);
export const $knownRolesNames = $cluster.map(selectors.knownRolesNames);

export const $bootstrapPanel = combine({
  visible: $bootstrapPanelVisible,
  pending: requestBootstrapFx.pending,
});
