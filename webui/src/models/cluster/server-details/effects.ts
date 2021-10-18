import graphql from 'src/api/graphql';
import type {
  BoxInfoQuery,
  BoxInfoQueryVariables,
  InstanceDataQuery,
  InstanceDataQueryVariables,
} from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import { firstServerDetailsQuery, nextServerDetailsQuery } from 'src/store/request/queries.graphql';

import { paths } from '../page';
import type { ClusterServerDetailsGateProps } from './types';

export const queryServerDetailsFx = app.domain.createEffect<InstanceDataQueryVariables, InstanceDataQuery>(
  'query server details effect',
  {
    handler: ({ uuid }) => graphql.fetch(firstServerDetailsQuery, { uuid }),
  }
);

export const queryServerDetailsBoxInfoFx = app.domain.createEffect<BoxInfoQueryVariables, BoxInfoQuery>(
  'query server details box info effect',
  {
    handler: ({ uuid }) => graphql.fetch(nextServerDetailsQuery, { uuid }),
  }
);

export const synchronizeServerDetailsLocationFx = app.domain.createEffect<
  { props: ClusterServerDetailsGateProps; open: boolean },
  void
>('synchronize server details location effect', {
  handler: ({ props, open }) => {
    const { history } = window.tarantool_enterprise_core;
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
  },
});
