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
  SetElectableServerEventPayload,
  Suggestion,
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

export const setElectableServerEvent =
  app.domain.createEvent<SetElectableServerEventPayload>('set electable server event');

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

// effects
export const queryServerListFx = app.domain.createEffect<ServerListQueryVariables, ServerListQuery>(
  'query server list effect'
);

export const queryClusterFx = app.domain.createEffect<void, GetClusterQuery>('query cluster effect');

export const queryClusterLegacyFx = app.domain.createEffect<void, void>('query cluster legacy effect');

export const promoteServerToLeaderFx = app.domain.createEffect<PromoteServerToLeaderEventPayload, void>(
  'promote server to leader'
);

export const setElectableServerFx = app.domain.createEffect<SetElectableServerEventPayload, void>(
  'set electable server'
);

export const disableOrEnableServerFx = app.domain.createEffect<DisableOrEnableServerEventPayload, void>(
  'disable or enable server'
);

export const requestBootstrapFx = app.domain.createEffect('request bootstrap');

// computed
export const $failoverParamsMode = $cluster.map((state) => selectors.failoverParamsMode(state) ?? null);
export const $knownRolesNames = $cluster.map(selectors.knownRolesNames);

export const $clusterCompressionInfo = $cluster.map(selectors.clusterCompressionInfo);

export const $suggestions = combine($clusterCompressionInfo, (info) => {
  return info.reduce((acc: Suggestion[], item) => {
    item.instance_compression_info.forEach((info) => {
      if (info.fields_be_compressed.length > 0) {
        acc.push({
          type: 'compression',
          meta: {
            instanceId: item.instance_id,
            spaceName: info.space_name,
            fields: info.fields_be_compressed.map(({ field_name, compression_percentage }) => ({
              name: field_name,
              compressionPercentage: compression_percentage,
            })),
          },
        });
      }
    });

    return acc;
  }, []);
});

export const $bootstrapPanel = combine({
  visible: $bootstrapPanelVisible,
  pending: requestBootstrapFx.pending,
});
