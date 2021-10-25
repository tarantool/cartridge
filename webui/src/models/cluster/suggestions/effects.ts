import graphql from 'src/api/graphql';
import type { EditServerInput } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import {
  configForceReapplyMutation,
  disableServersMutation,
  editTopologyMutation,
  restartReplicationMutation,
} from 'src/store/request/queries.graphql';

export const submitAdvertiseUriFx = app.domain.createEffect<EditServerInput[], void>('submit servers uri changes', {
  handler: (servers) => graphql.mutate(editTopologyMutation, { servers }),
});

export const submitDisableServersFx = app.domain.createEffect<string[], void>('submit disable servers effect', {
  handler: (uuids) => graphql.mutate(disableServersMutation, { uuids }),
});

export const submitRestartReplicationFx = app.domain.createEffect<string[], void>(
  'submit restart replications servers',
  {
    handler: (uuids) => graphql.mutate(restartReplicationMutation, { uuids }),
  }
);

export const submitForceApplyFx = app.domain.createEffect<string[], void>('submit disable servers', {
  handler: (uuids) => graphql.mutate(configForceReapplyMutation, { uuids }),
});
