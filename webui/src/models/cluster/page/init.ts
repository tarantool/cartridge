import { forward } from 'effector';

import { app } from 'src/models';
import { passResultOnEvent } from 'src/models/app/utils';

import { queryClusterErrorEvent, queryServerListErrorEvent } from '../server-list';
import {
  $clusterPageError,
  $clusterPageVisible,
  ClusterPageGate,
  clusterPageCloseEvent,
  clusterPageOpenEvent,
} from '.';

const { trueL } = app.utils;

forward({
  from: ClusterPageGate.open,
  to: clusterPageOpenEvent,
});

forward({
  from: ClusterPageGate.close,
  to: clusterPageCloseEvent,
});

// stores
$clusterPageVisible.on(clusterPageOpenEvent, trueL).reset(clusterPageCloseEvent);

$clusterPageError.on(queryClusterErrorEvent, passResultOnEvent).reset(clusterPageCloseEvent);
$clusterPageError.on(queryServerListErrorEvent, passResultOnEvent).reset(clusterPageCloseEvent);
