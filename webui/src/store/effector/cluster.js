// @flow
import { createEvent } from 'effector'
import { type ClusterPageState } from 'src/store/reducers/clusterPage.reducer';

export type ClusterDisableServersSuggestion = {
  uuid: string
}

export type ClusterRefineURISuggestion = {
  uri_new: string,
  uri_old: string,
  uuid: string
};

export type ClusterSuggestions = {
  refine_uri?: ClusterRefineURISuggestion[],
  disable_servers?: ClusterDisableServersSuggestion[]
};

export type ClusterState = {
  ...$Exact<ClusterPageState>,
  suggestions?: ClusterSuggestions
};

export const clusterPageMount = createEvent<mixed>('cluster page mount');
export const statsResponseSuccess = createEvent<ClusterState>('stats response success');
export const statsResponseError = createEvent<string>('stats response error');
