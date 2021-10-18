import { createGate } from 'effector-react';

import type { BoxInfoQuery, InstanceDataQuery } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';

import * as selectors from './selectors';
import type { ClusterServerDetailsGateProps, ServerDetails } from './types';

// exports
export { selectors };

// gates
export const ClusterServerDetailsGate = createGate<ClusterServerDetailsGateProps>('ClusterServerDetailsGate');

// events
export const queryServerDetailsSuccessEvent = app.domain.createEvent<InstanceDataQuery>(
  'query server details success event'
);

export const queryServerDetailsBoxInfoSuccessEvent = app.domain.createEvent<BoxInfoQuery>(
  'query server details box info success event'
);

export const serverDetailsModalOpenedEvent =
  app.domain.createEvent<ClusterServerDetailsGateProps>('server details modal opened');

export const serverDetailsModalClosedEvent = app.domain.createEvent('server details modal closed');

// stores
export const $selectedServerDetailsUuid = app.domain.createStore<string>('');
export const $isServerDetailsModalOpen = $selectedServerDetailsUuid.map(Boolean);
export const $serverDetails = app.domain.createStore<ServerDetails | null>(null);
