import type { GetClusterQuery, ServerListQuery } from 'src/generated/graphql-typing-ts';
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
export const queryClusterSuccessEvent = app.domain.createEvent<GetClusterQuery>('query cluster success event');

export const refreshClusterEvent = app.domain.createEvent('refresh cluster query event');

export const refreshServerListEvent = app.domain.createEvent('refresh server list query event');
export const setServerListIsDirtyEvent = app.domain.createEvent('set server list is dirty event');
export const refreshServerListAndSetDirtyEvent = app.domain.createEvent('refresh server list and set dirty event');

export const promoteServerToLeaderEvent = app.domain.createEvent<PromoteServerToLeaderEventPayload>(
  'promote server to leader event'
);

export const disableOrEnableServerEvent = app.domain.createEvent<DisableOrEnableServerEventPayload>(
  'disable or enable server event'
);

// stores
export const $serverList = app.domain.createStore<ServerList>(null);
export const $serverListIsDirty = app.domain.createStore<boolean>(false);
export const $cluster = app.domain.createStore<GetCluster>(null);

// computed stores
export const $failoverParamsMode = $cluster.map((state) => selectors.failoverParamsMode(state) ?? null);
export const $knownRolesNames = $cluster.map(selectors.knownRolesNames);
