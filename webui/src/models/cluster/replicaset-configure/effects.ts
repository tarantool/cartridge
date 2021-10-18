import graphql from 'src/api/graphql';
import { EditReplicasetInput, EditTopologyMutation } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import { editTopologyMutation } from 'src/store/request/queries.graphql';

import { paths } from '../page';
import type { ClusterReplicasetConfigureGateProps } from './types';

export const editReplicasetFx = app.domain.createEffect<EditReplicasetInput, EditTopologyMutation>('edit replicaset', {
  handler: ({ uuid, alias, roles, weight, all_rw, vshard_group, failover_priority, join_servers }) =>
    graphql.fetch(editTopologyMutation, {
      replicasets: [{ uuid, alias, roles, weight, all_rw, vshard_group, failover_priority, join_servers }],
    }),
});

export const synchronizeReplicasetConfigureLocationFx = app.domain.createEffect<
  { props: ClusterReplicasetConfigureGateProps; open: boolean },
  void
>('synchronize replicaset configure location effect', {
  handler: ({ props, open }) => {
    const { history } = window.tarantool_enterprise_core;
    const {
      location: { search },
    } = history;

    if (open) {
      if (!search.includes(props.uuid)) {
        history.push(paths.replicasetConfigure(props, search));
      }
    } else {
      if (search.includes(props.uuid)) {
        history.push(paths.root());
      }
    }
  },
});
