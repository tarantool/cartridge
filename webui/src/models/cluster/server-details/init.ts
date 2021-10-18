import { forward, guard, sample } from 'effector';

import { app } from 'src/models';

import { clusterPageClosedEvent } from '../page';
import { queryServerDetailsBoxInfoFx, queryServerDetailsFx, synchronizeServerDetailsLocationFx } from './effects';
import { mapServerDetailsToDescriptions } from './selectors';
import {
  $isServerDetailsModalOpen,
  $selectedServerDetailsUuid,
  $serverDetails,
  ClusterServerDetailsGate,
  queryServerDetailsBoxInfoSuccessEvent,
  queryServerDetailsSuccessEvent,
  serverDetailsModalClosedEvent,
  serverDetailsModalOpenedEvent,
} from '.';

const { not, voidL, createTimeoutFx, mapModalOpenedClosedEventPayload } = app.utils;

guard({
  source: ClusterServerDetailsGate.open,
  filter: $isServerDetailsModalOpen.map(not),
  target: serverDetailsModalOpenedEvent,
});

forward({
  from: ClusterServerDetailsGate.close,
  to: serverDetailsModalClosedEvent,
});

forward({
  from: serverDetailsModalOpenedEvent.map(mapModalOpenedClosedEventPayload(true)),
  to: synchronizeServerDetailsLocationFx,
});

sample({
  source: $selectedServerDetailsUuid.map((uuid) => ({ uuid })).map(mapModalOpenedClosedEventPayload(false)),
  clock: serverDetailsModalClosedEvent,
  target: synchronizeServerDetailsLocationFx,
});

guard({
  source: queryServerDetailsFx.doneData,
  filter: $isServerDetailsModalOpen,
  target: queryServerDetailsSuccessEvent,
});

guard({
  source: queryServerDetailsBoxInfoFx.doneData,
  filter: $isServerDetailsModalOpen,
  target: queryServerDetailsBoxInfoSuccessEvent,
});

createTimeoutFx('ServerDetailsTimeoutFx', {
  startEvent: serverDetailsModalOpenedEvent,
  stopEvent: serverDetailsModalClosedEvent.map(voidL),
  timeout: (): number => app.variables.cartridge_refresh_interval(),
  effect: async (counter, props): Promise<void> => {
    if (props) {
      if (counter === 0) {
        await queryServerDetailsFx(props);
      } else {
        await queryServerDetailsBoxInfoFx(props);
      }
    }
  },
});

// stores
$selectedServerDetailsUuid
  .on(serverDetailsModalOpenedEvent, (_, { uuid }) => uuid)
  .reset(serverDetailsModalClosedEvent)
  .reset(clusterPageClosedEvent);

$serverDetails
  .on(queryServerDetailsSuccessEvent, (_, result) => {
    const server = result?.servers?.[0];
    if (!server) {
      return;
    }

    return {
      server: server ?? undefined,
      descriptions: mapServerDetailsToDescriptions(result),
    };
  })
  .on(queryServerDetailsBoxInfoSuccessEvent, (state, result) => {
    const server = result?.servers?.[0];
    if (!state || !server) {
      return;
    }

    return {
      ...state,
      server,
    };
  })
  .reset(clusterPageClosedEvent);
