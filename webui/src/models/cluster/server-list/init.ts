import { forward, guard } from 'effector';
import { produce } from 'immer';
import { core } from '@tarantool.io/frontend-core';

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
  queryClusterLegacyFx,
  queryClusterSuccessEvent,
  queryServerListErrorEvent,
  queryServerListFx,
  queryServerListSuccessEvent,
  refreshServerListAndClusterEvent,
  requestBootstrapEvent,
  requestBootstrapFx,
  selectors,
  setElectableServerEvent,
  setElectableServerFx,
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
  from: setElectableServerEvent,
  to: setElectableServerFx,
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
  to: [queryClusterFx, queryClusterLegacyFx],
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
  from: setElectableServerFx.failData.map(mapErrorWithTitle('Electable state setting error')),
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
    const cnt = counter - 1;
    const withStats =
      cnt > -1 && (cnt % app.variables.cartridge_stat_period() === 0 || Boolean(hasUnConfiguredServers));
    return queryServerListFx({ withStats }).then(voidL);
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
          leader_autoreturn,
          autoreturn_delay,
          check_cookie_hash,
          mode,
          state_provider,
          etcd2_params,
          tarantool_params,
        } = next;

        exists(failover_timeout) && (failover_params.failover_timeout = failover_timeout);
        exists(fencing_enabled) && (failover_params.fencing_enabled = fencing_enabled);
        exists(fencing_timeout) && (failover_params.fencing_timeout = fencing_timeout);
        exists(fencing_pause) && (failover_params.fencing_pause = fencing_pause);
        exists(leader_autoreturn) && (failover_params.leader_autoreturn = leader_autoreturn);
        exists(autoreturn_delay) && (failover_params.autoreturn_delay = autoreturn_delay);
        exists(check_cookie_hash) && (failover_params.check_cookie_hash = check_cookie_hash);
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
    if (!prev || !prev.cluster) {
      return;
    }

    return produce(prev, (draft) => {
      if (draft.cluster && next.failover?.failover_params.mode) {
        draft.cluster.failover_params.mode = next.failover.failover_params.mode;
      }

      if (draft.cluster && next.cluster?.known_roles) {
        draft.cluster.knownRoles = next.cluster.known_roles;
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

queryClusterLegacyFx.use(() => void core.dispatch('cluster:reload_cluster_self', null));

promoteServerToLeaderFx.use(({ instanceUuid, replicasetUuid, force }) =>
  graphql.mutate(promoteFailoverLeaderMutation, {
    replicaset_uuid: replicasetUuid,
    instance_uuid: instanceUuid,
    force_inconsistency: force,
  })
);

setElectableServerFx.use(({ uuid, electable }) =>
  graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, electable }],
  })
);

disableOrEnableServerFx.use(({ uuid, disable }) =>
  graphql.mutate(editTopologyMutation, {
    servers: [{ uuid, disabled: disable }],
  })
);

requestBootstrapFx.use(() => graphql.mutate(bootstrapMutation));
