// @flow
import graphql from 'src/api/graphql';
import rest from 'src/api/rest';
import { getClusterSelf } from 'src/store/request/app.requests';
import {
  bootstrapMutation,
  changeFailoverMutation,
  editTopologyMutation,
  listQuery,
  listQueryWithoutStat,
  probeMutation,
  serverStatQuery
} from './queries.graphql';
import type { EditTopologyMutationVariables } from 'src/generated/graphql-typing'

const filterServerStat = response => {
  const serverStat
    = response.serverStat.filter(stat => stat.uuid && stat.statistics && !Array.isArray(stat.statistics));
  return {
    ...response,
    serverStat
  };
};

export function getPageData() {
  return graphql.fetch(listQuery)
    .then(
      ({
        cluster: {
          issues
        },
        ...response
      }) => filterServerStat({
        ...response,
        issues
      })
    );
}

type RefreshListsArgs = {
  shouldRequestStat?: boolean
};

export function refreshLists(params: RefreshListsArgs = {}) {
  const graph = params.shouldRequestStat ? listQuery : listQueryWithoutStat;
  return graphql.fetch(graph)
    .then(
      params.shouldRequestStat
        ? ({
          cluster: {
            issues
          },
          ...response
        }) => filterServerStat({
          ...response,
          issues
        })
        : null
    );
}

export function getServerStat() {
  return graphql.fetch(serverStatQuery)
    .then(filterServerStat);
}

export function bootstrapVshard() {
  return graphql.mutate(bootstrapMutation);
}

type ProbeServerArgs = {
  uri: string
};

export function probeServer(params: ProbeServerArgs) {
  return graphql.mutate(probeMutation, params);
}

type JoinServerArgs = {
  uri: string,
  uuid: string
};

export function joinServer({ uri, uuid }: JoinServerArgs) {
  const mutationVariables: EditTopologyMutationVariables = {
    replicasets: [
      { uuid, join_servers: [{ uri }] }
    ]
  };

  return graphql.mutate(editTopologyMutation, mutationVariables);
}

export type CreateReplicasetArgs = {
  alias: string,
  all_rw: boolean,
  roles: string[],
  uri: string,
  vshard_group: string,
  weight: number
};

export function createReplicaset(
  {
    alias,
    all_rw,
    roles,
    uri,
    vshard_group,
    weight
  }: CreateReplicasetArgs
) {
  const mutationVariables: EditTopologyMutationVariables = {
    replicasets: [
      {
        alias,
        all_rw,
        roles,
        vshard_group,
        weight,
        join_servers: [{ uri }]
      }
    ]
  };

  return graphql.mutate(editTopologyMutation, mutationVariables);
}

type ExpelServerArgs = {
  uuid: string
};

export function expelServer({ uuid }: ExpelServerArgs) {
  const mutationVariables: EditTopologyMutationVariables = {
    servers: [
      { uuid, expelled: true }
    ]
  };

  return graphql.mutate(editTopologyMutation, mutationVariables);
}

export type EditReplicasetArgs = {
  alias: string,
  all_rw: boolean,
  master: string[],
  roles: string[],
  uuid: string,
  vshard_group: string,
  weight: number
};

export function editReplicaset(
  {
    alias,
    all_rw,
    master,
    roles,
    uuid,
    vshard_group,
    weight
  }: EditReplicasetArgs
) {
  const mutationVariables: EditTopologyMutationVariables = {
    replicasets: [
      {
        alias,
        all_rw,
        failover_priority: master,
        roles,
        uuid,
        vshard_group,
        weight
      }
    ]
  };

  return graphql.mutate(editTopologyMutation, mutationVariables);
}

type UploadConfigParams = { data: FormData };

export async function uploadConfig(params: UploadConfigParams) {
  return rest.put(process.env.REACT_APP_CONFIG_ENDPOINT, params.data, {
    headers: { 'Content-Type': 'application/yaml;charset=UTF-8' }
  });
}

type ChangeFailoverArgs = { enabled: boolean };

export async function changeFailover(params: ChangeFailoverArgs) {
  const changeFailoverResponse = await graphql.mutate(changeFailoverMutation, params);
  const clusterSelfResponse = await getClusterSelf();
  return {
    changeFailoverResponse: {
      changeFailover: changeFailoverResponse,
      clusterSelf: clusterSelfResponse
    }
  };
}
