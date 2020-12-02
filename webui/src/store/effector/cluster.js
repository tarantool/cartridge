// @flow
import { createEvent } from 'effector'
import { type ClusterPageState } from 'src/store/reducers/clusterPage.reducer';

export type ClusterRefineURISuggestion = {
  uri_new: string,
  uri_old: string,
  uuid: string
};

export type ClusterSuggestions = {
  refine_uri?: ClusterRefineURISuggestion[]
};

export type ClusterState = {
  ...$Exact<ClusterPageState>,
  suggestions?: ClusterSuggestions
};

export const clusterPageMount = createEvent<mixed>('cluster page mount');
export const statsResponseSuccess = createEvent<ClusterState>('stats response success');
export const statsResponseError = createEvent<string>('stats response error');
