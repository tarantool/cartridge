import { createGate } from 'effector-react';

import type {
  BoxInfoQuery,
  BoxInfoQueryVariables,
  InstanceDataQuery,
  InstanceDataQueryVariables,
} from 'src/generated/graphql-typing-ts';
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
export const $serverDetailsModalVisible = $selectedServerDetailsUuid.map(Boolean);
export const $serverDetails = app.domain.createStore<ServerDetails | null>(null);

// effects
export const queryServerDetailsFx = app.domain.createEffect<InstanceDataQueryVariables, InstanceDataQuery>(
  'query server details effect'
);

export const queryServerDetailsBoxInfoFx = app.domain.createEffect<BoxInfoQueryVariables, BoxInfoQuery>(
  'query server details box info effect'
);

export const synchronizeServerDetailsLocationFx = app.domain.createEffect<
  { props: ClusterServerDetailsGateProps; open: boolean },
  void
>('synchronize server details location effect');
