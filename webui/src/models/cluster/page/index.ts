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
export const clusterPageOpenedEvent = app.domain.createEvent('cluster page opened');
export const clusterPageClosedEvent = app.domain.createEvent('cluster page closed');

// stores
export const $isClusterPageOpen = app.domain.createStore(false);

export const $isClusterPageReady = combine([$serverList, $cluster], ([serverList, cluster]) =>
  Boolean(serverList && cluster)
);
