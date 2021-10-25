import { combine } from 'effector';

import type {
  DisableServerSuggestion,
  ForceApplySuggestion,
  RefineUriSuggestion,
  RestartReplicationSuggestion,
} from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import {
  submitAdvertiseUriFx,
  submitDisableServersFx,
  submitForceApplyFx,
  submitRestartReplicationFx,
} from './effects';
import type { CheckedServers, ForceApplySuggestionByReason, SuggestionsPanelsVisibility } from './types';

// events
export const advertiseURIApplyClick = app.domain.createEvent<unknown>('advertise URI apply click');
export const advertiseURIDetailsClick = app.domain.createEvent<unknown>('advertise URI details click');
export const disableServersApplyClick = app.domain.createEvent<unknown>('disable servers apply click');
export const disableServersDetailsClick = app.domain.createEvent<unknown>('disable servers details click');
export const restartReplicationsApplyClick = app.domain.createEvent<unknown>('restart replications apply click');
export const restartReplicationsDetailsClick = app.domain.createEvent<unknown>('restart replications details click');
export const forceApplyConfApplyClick = app.domain.createEvent<unknown>('force apply config apply click');
export const forceApplyConfDetailsClick = app.domain.createEvent<unknown>('force apply config details click');
export const forceApplyInstanceCheck = app.domain.createEvent<string>('force apply check instance');
export const forceApplyReasonCheck = app.domain.createEvent<string>('force apply check instances with same reason');
export const forceApplyReasonUncheck = app.domain.createEvent<string>('force apply uncheck instances with same reason');
export const detailsClose = app.domain.createEvent('details modal close');

// stores
export const $advertiseURISuggestion = app.domain.createStore<RefineUriSuggestion[] | null>(null);

export const $disableServersSuggestion = app.domain.createStore<DisableServerSuggestion[] | null>(null);

export const $forceApplySuggestion = app.domain.createStore<ForceApplySuggestion[] | null>(null);

export const $restartReplicationSuggestion = app.domain.createStore<RestartReplicationSuggestion[] | null>(null);

export const $forceApplyModalCheckedServers = app.domain.createStore<CheckedServers>({});

export const $advertiseURIModalVisible = app.domain.createStore(false);

export const $disableServerModalVisible = app.domain.createStore(false);

export const $restartReplicationsModalVisible = app.domain.createStore(false);

export const $forceApplyModalVisible = app.domain.createStore(false);

export const $advertiseURIError = app.domain.createStore<string | null>(null);

export const $disableServersError = app.domain.createStore<string | null>(null);

export const $restartReplicationsError = app.domain.createStore<string | null>(null);

export const $forceApplyError = app.domain.createStore<string | null>(null);

// computed
export const $forceApplySuggestionByReason = $forceApplySuggestion.map((state) => {
  const result: ForceApplySuggestionByReason = [
    ['operation_error', []],
    ['config_error', []],
  ];

  if (!state) {
    return result;
  }

  return state.reduce((acc, { config_locked, config_mismatch, operation_error, uuid }) => {
    if (operation_error) {
      acc[0][1].push(uuid);
    }

    if (config_locked || config_mismatch) {
      acc[1][1].push(uuid);
    }

    return acc;
  }, result);
});

export const $panelsVisibility = combine(
  {
    advertiseURI: $advertiseURISuggestion,
    disableServers: $disableServersSuggestion,
    forceApply: $forceApplySuggestion,
    restartReplication: $restartReplicationSuggestion,
  },
  ({ advertiseURI, disableServers, forceApply, restartReplication }): SuggestionsPanelsVisibility => ({
    advertiseURI: Boolean(advertiseURI),
    disableServers: Boolean(disableServers && disableServers.length > 0),
    forceApply: Boolean(forceApply && forceApply.length > 0),
    restartReplication: Boolean(restartReplication && restartReplication.length > 0),
  })
);

export const $advertiseURIModal = combine({
  visible: $advertiseURIModalVisible,
  suggestions: $advertiseURISuggestion,
  error: $advertiseURIError,
  pending: submitAdvertiseUriFx.pending,
});

export const $disableServersModal = combine({
  visible: $disableServerModalVisible,
  suggestions: $disableServersSuggestion,
  error: $disableServersError,
  pending: submitDisableServersFx.pending,
});

export const $restartReplicationsModal = combine({
  visible: $restartReplicationsModalVisible,
  suggestions: $restartReplicationSuggestion,
  error: $restartReplicationsError,
  pending: submitRestartReplicationFx.pending,
});

export const $forceApplyModal = combine({
  visible: $forceApplyModalVisible,
  suggestions: $forceApplySuggestionByReason,
  error: $forceApplyError,
  pending: submitForceApplyFx.pending,
  checked: $forceApplyModalCheckedServers,
});
