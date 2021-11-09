import { forward, sample } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import {
  configForceReapplyMutation,
  disableServersMutation,
  editTopologyMutation,
  restartReplicationMutation,
} from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import { $serverList, queryServerListErrorEvent, refreshServerListAndClusterEvent } from '../server-list';
import type { CheckedServers, ForceApplySuggestionByReason } from './types';
import {
  $advertiseURIError,
  $advertiseURIModalVisible,
  $advertiseURISuggestion,
  $disableServerModalVisible,
  $disableServersError,
  $disableServersSuggestion,
  $forceApplyError,
  $forceApplyModal,
  $forceApplyModalCheckedServers,
  $forceApplyModalVisible,
  $forceApplySuggestion,
  $restartReplicationSuggestion,
  $restartReplicationsError,
  $restartReplicationsModalVisible,
  advertiseURIApplyClick,
  advertiseURIDetailsClick,
  detailsClose,
  disableServersApplyClick,
  disableServersDetailsClick,
  forceApplyConfApplyClick,
  forceApplyConfDetailsClick,
  forceApplyInstanceCheck,
  forceApplyReasonCheck,
  forceApplyReasonUncheck,
  restartReplicationsApplyClick,
  restartReplicationsDetailsClick,
  submitAdvertiseUriFx,
  submitDisableServersFx,
  submitForceApplyFx,
  submitRestartReplicationFx,
} from '.';

const { trueL, equals, passErrorMessageOnEvent } = app.utils;

sample({
  source: $advertiseURISuggestion,
  clock: advertiseURIApplyClick,
  fn: (servers) => (servers || []).map(({ uuid, uri_new: uri }) => ({ uuid, uri })),
  target: submitAdvertiseUriFx,
});

sample({
  source: $disableServersSuggestion,
  clock: disableServersApplyClick,
  fn: (servers) => (servers || []).map(({ uuid }) => uuid),
  target: submitDisableServersFx,
});

sample({
  source: $restartReplicationSuggestion,
  clock: restartReplicationsApplyClick,
  fn: (servers) => (servers || []).map(({ uuid }) => uuid),
  target: submitRestartReplicationFx,
});

sample({
  source: $forceApplyModalCheckedServers,
  clock: forceApplyConfApplyClick,
  fn: (uuids) =>
    Object.entries(uuids)
      .filter(([, checked]) => checked)
      .map(([uuid]) => uuid),
  target: submitForceApplyFx,
});

const createCheckAllFn =
  (check: boolean) =>
  (
    {
      suggestions,
      checked,
    }: {
      suggestions: ForceApplySuggestionByReason;
      checked: CheckedServers;
    },
    reason: string
  ): CheckedServers => {
    const uuids = suggestions.find(([name]) => reason === name)?.[1] ?? [];
    return uuids.reduce((acc, uuid) => {
      acc[uuid] = check;
      return acc;
    }, checked);
  };

sample({
  source: $forceApplyModal,
  clock: forceApplyReasonCheck,
  fn: createCheckAllFn(true),
  target: $forceApplyModalCheckedServers,
});

sample({
  source: $forceApplyModal,
  clock: forceApplyReasonUncheck,
  fn: createCheckAllFn(false),
  target: $forceApplyModalCheckedServers,
});

forward({
  from: [
    submitAdvertiseUriFx.done,
    submitDisableServersFx.done,
    submitRestartReplicationFx.done,
    submitForceApplyFx.done,
  ],
  to: refreshServerListAndClusterEvent,
});

// stores
$advertiseURISuggestion
  .on($serverList, (prev, next) => {
    const refine_uri = next?.cluster?.suggestions?.refine_uri || null;
    return equals(prev, refine_uri) ? prev : refine_uri;
  })
  .reset(queryServerListErrorEvent)
  .reset(clusterPageCloseEvent);

$disableServersSuggestion
  .on($serverList, (prev, next) => {
    const disable_servers = next?.cluster?.suggestions?.disable_servers;
    return equals(prev, disable_servers) ? prev : disable_servers;
  })
  .reset(queryServerListErrorEvent)
  .reset(clusterPageCloseEvent);

$forceApplySuggestion
  .on($serverList, (prev, next) => {
    const force_apply = next?.cluster?.suggestions?.force_apply || null;
    return equals(prev, force_apply) ? prev : force_apply;
  })
  .reset(queryServerListErrorEvent)
  .reset(clusterPageCloseEvent);

$restartReplicationSuggestion
  .on($serverList, (prev, next) => {
    const restart_replication = next?.cluster?.suggestions?.restart_replication || null;
    return equals(prev, restart_replication) ? prev : restart_replication;
  })
  .reset(queryServerListErrorEvent)
  .reset(clusterPageCloseEvent);

$forceApplyModalCheckedServers
  .on($forceApplySuggestion, (prevState, state) =>
    (state || []).reduce((acc, { uuid }) => {
      acc[uuid] = prevState && uuid in prevState ? prevState[uuid] : true;
      return acc;
    }, {})
  )
  .on(forceApplyInstanceCheck, (state, uuid) => ({ ...state, [uuid]: !state[uuid] }));

$advertiseURIModalVisible
  .on(advertiseURIDetailsClick, trueL)
  .reset(submitAdvertiseUriFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$disableServerModalVisible
  .on(disableServersDetailsClick, trueL)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$restartReplicationsModalVisible
  .on(restartReplicationsDetailsClick, trueL)
  .reset(submitRestartReplicationFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$forceApplyModalVisible
  .on(forceApplyConfDetailsClick, trueL)
  .reset(submitForceApplyFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$advertiseURIError
  .on(submitAdvertiseUriFx.failData, passErrorMessageOnEvent)
  .reset(submitAdvertiseUriFx)
  .reset(submitAdvertiseUriFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$disableServersError
  .on(submitDisableServersFx.failData, passErrorMessageOnEvent)
  .reset(submitDisableServersFx)
  .reset(submitDisableServersFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$restartReplicationsError
  .on(submitRestartReplicationFx.failData, passErrorMessageOnEvent)
  .reset(submitRestartReplicationFx)
  .reset(submitRestartReplicationFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

$forceApplyError
  .on(submitForceApplyFx.failData, passErrorMessageOnEvent)
  .reset(submitForceApplyFx)
  .reset(submitForceApplyFx.done)
  .reset(detailsClose)
  .reset(clusterPageCloseEvent);

// effects
submitAdvertiseUriFx.use((servers) => graphql.mutate(editTopologyMutation, { servers }));

submitDisableServersFx.use((uuids) => graphql.mutate(disableServersMutation, { uuids }));

submitRestartReplicationFx.use((uuids) => graphql.mutate(restartReplicationMutation, { uuids }));

submitForceApplyFx.use((uuids) => graphql.mutate(configForceReapplyMutation, { uuids }));
