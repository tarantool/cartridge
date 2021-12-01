import { combine } from 'effector';
import { createGate } from 'effector-react';

import { app } from 'src/models';

import { $cluster, $serverList } from '../server-list';
import * as paths from './paths';

// exports
export { paths };

// gates
export const ClusterPageGate = createGate('ClusterPageGate');

// events
export const clusterPageOpenEvent = app.domain.createEvent('cluster page open event');
export const clusterPageCloseEvent = app.domain.createEvent('cluster page close event');

// stores
export const $clusterPageVisible = app.domain.createStore(false);
export const $clusterPageError = app.domain.createStore<Error | null>(null);

export const $clusterPage = combine({
  visible: $clusterPageVisible,
  error: $clusterPageError,
  ready: combine([$serverList, $cluster], ([serverList, cluster]) => Boolean(serverList && cluster)),
});
