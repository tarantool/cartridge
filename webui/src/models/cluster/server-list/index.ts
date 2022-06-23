import { combine } from 'effector';

import type { GetClusterQuery, ServerListQuery, ServerListQueryVariables } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

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
export const setRolesFiltered = app.domain.createEvent<string>('set filtered roles event');
export const setRatingFiltered = app.domain.createEvent<string>('set filtered rating event');

// stores
export const $rolesFilter = app.domain.createStore<string>('');
export const $ratingFilter = app.domain.createStore<string>('');
export const $serverList = app.domain.createStore<ServerList>(null);
export const $cluster = app.domain.createStore<GetCluster>(null);

export const $bootstrapPanelVisible = app.domain.createStore(false);

// effects
export const queryServerListFx = app.domain.createEffect<ServerListQueryVariables, ServerListQuery>(
  'query server list effect'
);

export const queryClusterFx = app.domain.createEffect<void, GetClusterQuery>('query cluster effect');

export const queryClusterLegacyFx = app.domain.createEffect<void, void>('query cluster legacy effect');

export const promoteServerToLeaderFx = app.domain.createEffect<PromoteServerToLeaderEventPayload, void>(
  'promote server to leader'
);

export const disableOrEnableServerFx = app.domain.createEffect<DisableOrEnableServerEventPayload, void>(
  'disable or enable server'
);

export const requestBootstrapFx = app.domain.createEffect('request bootstrap');

// computed
export const $failoverParamsMode = $cluster.map((state) => selectors.failoverParamsMode(state) ?? null);
export const $knownRolesNames = $cluster.map(selectors.knownRolesNames);
export const $replicasetsList = $serverList.map((state) => selectors.replicasetList(state) ?? null);

$rolesFilter.on(setRolesFiltered, (_, payload) => payload);
$ratingFilter.on(setRatingFiltered, (_, payload) => payload);

export const $filteredReplicasetList = combine(
  $replicasetsList,
  $rolesFilter,
  $ratingFilter,
  (replicasetsList, rolesFilter, leaderFilter) => {
    const filteredData = selectors.replicasetListSearchable(replicasetsList);
    const filteredRoles = filters.filterSearchableReplicasetList(filteredData, rolesFilter);
    return filters.filteredReplicaIsLeader(filteredRoles, leaderFilter);
  }
);

export const $bootstrapPanel = combine({
  visible: $bootstrapPanelVisible,
  pending: requestBootstrapFx.pending,
});
