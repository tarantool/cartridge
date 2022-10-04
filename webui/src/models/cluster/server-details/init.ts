import { forward, guard, sample } from 'effector';
import { core } from '@tarantool.io/frontend-core';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { firstServerDetailsQuery, nextServerDetailsQuery } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent, paths } from '../page';
import { mapServerDetailsToDescriptions } from './selectors';
import {
  $selectedServerDetailsUuid,
  $serverDetails,
  $serverDetailsModalVisible,
  ClusterServerDetailsGate,
  queryServerDetailsBoxInfoFx,
  queryServerDetailsBoxInfoSuccessEvent,
  queryServerDetailsFx,
  queryServerDetailsSuccessEvent,
  serverDetailsModalClosedEvent,
  serverDetailsModalOpenedEvent,
  synchronizeServerDetailsLocationFx,
} from '.';

const { not, createTimeoutFx, mapModalOpenedClosedEventPayload, passResultPathOnEvent } = app.utils;

guard({
  source: ClusterServerDetailsGate.open,
  filter: $serverDetailsModalVisible.map(not),
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
  filter: $serverDetailsModalVisible,
  target: queryServerDetailsSuccessEvent,
});

guard({
  source: queryServerDetailsBoxInfoFx.doneData,
  filter: $serverDetailsModalVisible,
  target: queryServerDetailsBoxInfoSuccessEvent,
});

createTimeoutFx('ServerDetailsTimeoutFx', {
  startEvent: serverDetailsModalOpenedEvent,
  stopEvent: serverDetailsModalClosedEvent,
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
  .on(serverDetailsModalOpenedEvent, passResultPathOnEvent('uuid'))
  .reset(serverDetailsModalClosedEvent)
  .reset(clusterPageCloseEvent);

$serverDetails
  .on(queryServerDetailsSuccessEvent, (_, result) => {
    console.log('effector server datails', result);
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
  .reset(serverDetailsModalClosedEvent)
  .reset(serverDetailsModalOpenedEvent)
  .reset(clusterPageCloseEvent);

// effects
queryServerDetailsFx.use(({ uuid }) => graphql.fetch(firstServerDetailsQuery, { uuid }));

queryServerDetailsBoxInfoFx.use(({ uuid }) => graphql.fetch(nextServerDetailsQuery, { uuid }));

synchronizeServerDetailsLocationFx.use(({ props, open }) => {
  const { history } = core;
  const {
    location: { pathname },
  } = history;

  // eslint-disable-next-line no-console
  if (open) {
    if (!pathname.includes(props.uuid)) {
      history.push(paths.serverDetails(props));
    }
  } else {
    if (pathname.includes(props.uuid)) {
      history.push(paths.root());
    }
  }
});
