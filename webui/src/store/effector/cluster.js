// @flow
import { createEvent } from 'effector'
import { type ClusterPageState } from 'src/store/reducers/clusterPage.reducer';
import type { Suggestions } from 'src/generated/graphql-typing';
export type ClusterState = {
  ...$Exact<ClusterPageState>,
  suggestions?: Suggestions
};

export const clusterPageMount = createEvent<mixed>('cluster page mount');
export const statsResponseSuccess = createEvent<ClusterState>('stats response success');
export const statsResponseError = createEvent<string>('stats response error');
