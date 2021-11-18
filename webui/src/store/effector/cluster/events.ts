import { createEvent } from 'effector';

import type { ClusterState } from './types';

export const clusterPageMount = createEvent('cluster page mount');
export const statsResponseSuccess = createEvent<ClusterState>('stats response success');
export const statsResponseError = createEvent<string>('stats response error');
