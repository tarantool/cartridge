import { forward, guard } from 'effector';
import { produce } from 'immer';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import {
  bootstrapMutation,
  editTopologyMutation,
  getClusterQuery,
  listQuery,
  promoteFailoverLeaderMutation,
} from 'src/store/request/queries.graphql';

import { changeFailoverEvent } from '../failover';
import { $clusterPageVisible, clusterPageCloseEvent, clusterPageOpenEvent } from '../page';
import {
  $bootstrapPanelVisible,
  $cluster,
  $serverList,
  disableOrEnableServerEvent,
  disableOrEnableServerFx,
  hideBootstrapPanelEvent,
  promoteServerToLeaderEvent,
  promoteServerToLeaderFx,
  queryClusterErrorEvent,
  queryClusterFx,
  queryClusterSuccessEvent,
  queryServerListErrorEvent,
  queryServerListFx,
  queryServerListSuccessEvent,
  refreshServerListAndClusterEvent,
  requestBootstrapEvent,
  requestBootstrapFx,
  selectors,
  showBootstrapPanelEvent,
} from '.';

const { notifyErrorEvent, notifyEvent, notifySuccessEvent, authAccessDeniedEvent } = app;
const { createTimeoutFx, exists, voidL, trueL, combineResultOnEvent, passResultOnEvent, mapErrorWithTitle } = app.utils;

const mapWithStat = () => ({ withStats: true });

forward({
  from: clusterPageOpenEvent,
  to: queryClusterFx,
});

forward({
  from: promoteServerToLeaderEvent,
  to: promoteServerToLeaderFx,
});

forward({
  from: disableOrEnableServerEvent,
  to: disableOrEnableServerFx,
});

forward({
  from: refreshServerListAndClusterEvent.map(mapWithStat),
  to: queryServerListFx,
});

forward({
  from: refreshServerListAndClusterEvent,
  to: queryClusterFx,
});

forward({
  from: requestBootstrapEvent,
  to: requestBootstrapFx,
});

guard({
  source: queryServerListFx.doneData,
  filter: $clusterPageVisible,
  target: queryServerListSuccessEvent,
});

guard({
  source: queryServerListFx.failData,
  filter: $clusterPageVisible,
  target: queryServerListErrorEvent,
});

guard({
  source: queryClusterFx.doneData,
  filter: $clusterPageVisible,
  target: queryClusterSuccessEvent,
});

guard({
  source: queryClusterFx.failData,
  filter: $clusterPageVisible,
  target: queryClusterErrorEvent,
});

guard({
  source: requestBootstrapFx.finally,
  filter: $clusterPageVisible,
  target: refreshServerListAndClusterEvent,
});

// notifications
forward({
  from: promoteServerToLeaderFx.done.map(() => ({
    title: 'Failover',
    message: 'Leader promotion successful',
  })),
  to: notifyEvent,
});

forward({
  from: requestBootstrapFx.done.map(() => 'VShard bootstrap is OK. Please wait for list refresh...'),
  to: notifySuccessEvent,
});

forward({
  from: promoteServerToLeaderFx.failData.map(mapErrorWithTitle('Leader promotion error')),
  to: notifyErrorEvent,
});

forward({
  from: disableOrEnableServerFx.failData.map(mapErrorWithTitle('Disabled state setting error')),
  to: notifyErrorEvent,
});

forward({
  from: requestBootstrapFx.failData,
  to: notifyErrorEvent,
});

createTimeoutFx('ServerListTimeoutFx', {
  startEvent: clusterPageOpenEvent,
  stopEvent: clusterPageCloseEvent,
  source: $serverList.map((state) => selectors.unConfiguredServerList(state).length > 0),
  timeout: (): number => app.variables.cartridge_refresh_interval(),
  effect: (counter: number, _, hasUnConfiguredServers): Promise<void> => {
    return queryServerListFx({
      withStats: counter % app.variables.cartridge_stat_period() === 0 || Boolean(hasUnConfiguredServers),
    }).then(voidL);
  },
});

createTimeoutFx('QueryClusterTimeoutFx', {
  startEvent: requestBootstrapFx.done,
  stopEvent: queryClusterFx.done,
  timeout: 2000,
  effect: (): Promise<void> => queryClusterFx().then(voidL),
});

// stores
$serverList.on(queryServerListSuccessEvent, combineResultOnEvent).reset(clusterPageCloseEvent);

$cluster
  .on(queryClusterSuccessEvent, passResultOnEvent)
  .on(authAccessDeniedEvent, (state) => {
    return produce(state, (draft) => {
      if (draft?.cluster) {
        draft.cluster.authParams.implements_check_password = true;
      }
    });
  })
  .on(changeFailoverEvent, (prev, next) => {
    if (!prev || !prev.cluster) {
      return;
    }

    return produce(prev, (draft) => {
      if (draft.cluster) {
        const { failover_params } = draft.cluster;
        const {
          failover_timeout,
          fencing_enabled,
          fencing_timeout,
          fencing_pause,
          mode,
          state_provider,
          etcd2_params,
          tarantool_params,
        } = next;

        exists(failover_timeout) && (failover_params.failover_timeout = failover_timeout);
        exists(fencing_enabled) && (failover_params.fencing_enabled = fencing_enabled);
        exists(fencing_timeout) && (failover_params.fencing_timeout = fencing_timeout);
        exists(fencing_pause) && (failover_params.fencing_pause = fencing_pause);
        exists(mode) && (failover_params.mode = mode);
        exists(state_provider) && (failover_params.state_provider = state_provider);
        // etcd2_params
        if (failover_params.etcd2_params && etcd2_params) {
          const { password, lock_delay, endpoints, username, prefix } = etcd2_params;
          exists(password) && (failover_params.etcd2_params.password = password);
          exists(lock_delay) && (failover_params.etcd2_params.lock_delay = lock_delay);
          exists(endpoints) && (failover_params.etcd2_params.endpoints = endpoints);
          exists(username) && (failover_params.etcd2_params.username = username);
          exists(prefix) && (failover_params.etcd2_params.prefix = prefix);
        }
        // tarantool_params
        if (failover_params.tarantool_params && tarantool_params) {
          const { password, uri } = tarantool_params;
          exists(password) && (failover_params.tarantool_params.password = password);
          exists(uri) && (failover_params.tarantool_params.uri = uri);
        }
      }
    });
  })
  .on(queryServerListSuccessEvent, (prev, next) => {
    if (!prev || !prev.cluster || !next.failover?.failover_params.mode) {
      return;
    }

    const mode = next.failover.failover_params.mode;
    return produce(prev, (draft) => {
      if (draft.cluster) {
        draft.cluster.failover_params.mode = mode;
      }
    });
  })
  .reset(clusterPageCloseEvent);

$bootstrapPanelVisible
  .on(showBootstrapPanelEvent, trueL)
  .on(requestBootstrapFx.finally, trueL)
  .reset(requestBootstrapFx)
  .reset(hideBootstrapPanelEvent)
  .reset(clusterPageCloseEvent);

// effects
queryServerListFx.use(({ withStats }) => graphql.fetch(listQuery, { withStats }));

queryClusterFx.use(() => graphql.fetch(getClusterQuery));

promoteServerToLeaderFx.use(({ instanceUuid, replicasetUuid, force }) =>
  graphql.mutate(promoteFailoverLeaderMutation, {
    replicaset_uuid: replicasetUuid,
    instance_uuid: instanceUuid,
    force_inconsistency: force,
  })
);

disableOrEnableServerFx.use(({ uuid, disable }) =>
  graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, disabled: disable }],
  })
);

requestBootstrapFx.use(() => graphql.mutate(bootstrapMutation));
