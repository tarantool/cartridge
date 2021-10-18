import graphql from 'src/api/graphql';
import type { GetClusterQuery, ServerListQuery, ServerListQueryVariables } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import {
  editTopologyMutation,
  getClusterQuery,
  listQuery,
  promoteFailoverLeaderMutation,
} from 'src/store/request/queries.graphql';

import type { DisableOrEnableServerEventPayload, PromoteServerToLeaderEventPayload } from './types';

// effects
export const queryServerListFx = app.domain.createEffect<ServerListQueryVariables, ServerListQuery>(
  'query server list effect',
  {
    handler: ({ withStats }) => graphql.fetch(listQuery, { withStats }),
  }
);

export const queryClusterFx = app.domain.createEffect<void, GetClusterQuery>('query cluster effect', {
  handler: () => graphql.fetch(getClusterQuery),
});

export const promoteServerToLeaderFx = app.domain.createEffect<PromoteServerToLeaderEventPayload, void>(
  'promote server to leader',
  {
    handler: ({ instanceUuid, replicasetUuid, force }) =>
      graphql.mutate(promoteFailoverLeaderMutation, {
        replicaset_uuid: replicasetUuid,
        instance_uuid: instanceUuid,
        force_inconsistency: force,
      }),
  }
);

export const disableOrEnableServerFx = app.domain.createEffect<DisableOrEnableServerEventPayload, void>(
  'disable or enable server',
  {
    handler: ({ uuid, disable }) =>
      graphql.mutate(editTopologyMutation, {
        servers: [{ uuid, disabled: disable }],
      }),
  }
);
