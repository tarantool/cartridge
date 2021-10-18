import { forward } from 'effector';

import { app } from 'src/models';

import { $isClusterPageOpen, ClusterPageGate, clusterPageClosedEvent, clusterPageOpenedEvent } from '.';

const { trueL } = app.utils;

forward({
  from: ClusterPageGate.open,
  to: clusterPageOpenedEvent,
});

forward({
  from: ClusterPageGate.close,
  to: clusterPageClosedEvent,
});

// stores
$isClusterPageOpen.on(clusterPageOpenedEvent, trueL).reset(clusterPageClosedEvent);
