import graphql from 'src/api/graphql';
import { EditTopologyMutation } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { paths } from '../page';
import type { ClusterServeConfigureGateProps, CreateReplicasetProps, JoinReplicasetProps } from './types';

export const createReplicasetFx = app.domain.createEffect<CreateReplicasetProps, EditTopologyMutation>(
  'create replicaset',
  {
    handler: ({ alias, roles, weight, all_rw, vshard_group, join_servers }) =>
      graphql.fetch(editTopologyMutation, {
        replicasets: [
          {
            alias: alias || null,
            roles,
            weight: weight || null,
            all_rw,
            vshard_group: vshard_group || null,
            join_servers,
          },
        ],
      }),
  }
);

export const joinReplicasetFx = app.domain.createEffect<JoinReplicasetProps, EditTopologyMutation>('join replicaset', {
  handler: ({ uri, uuid }) =>
    graphql.fetch(editTopologyMutation, {
      replicasets: [{ uuid, join_servers: [{ uri }] }],
    }),
});

export const synchronizeServerConfigureLocationFx = app.domain.createEffect<
  { props: ClusterServeConfigureGateProps; open: boolean },
  void
>('synchronize server configure location effect', {
  handler: ({ props, open }) => {
    const { history } = window.tarantool_enterprise_core;
    const {
      location: { search },
    } = history;

    if (open) {
      if (!search.includes(props.uri)) {
        history.push(paths.serverConfigure(props));
      }
    } else {
      if (search.includes(props.uri)) {
        history.push(paths.root());
      }
    }
  },
});
