import { InputMaybe, LabelInput } from 'src/generated/graphql-typing-ts';
import { app } from 'src/models';
import type { Maybe } from 'src/models';

import type {
  GetCluster,
  GetClusterAuthParams,
  GetClusterCluster,
  GetClusterClusterSelf,
  GetClusterFailoverParams,
  GetClusterRole,
  GetClusterVshardGroup,
  KnownRolesNamesResult,
  ServerList,
  ServerListClusterIssue,
  ServerListReplicaset,
  ServerListReplicasetSearchable,
  ServerListReplicasetServer,
  ServerListServer,
  ServerListServerStat,
} from './types';

const { compact, uniq, pipe, map } = app.utils;

// flags
export const isClusterSelfConfigured = (
  clusterSelf: { uuid?: string | null | undefined } | null | undefined
): boolean => Boolean(clusterSelf?.uuid);

export const serverRo = (server: ServerListServer): boolean | undefined => server.boxinfo?.general?.ro;

export const replicasetServerRo = (server: ServerListReplicasetServer): boolean | undefined =>
  server.boxinfo?.general?.ro;

export const clusterVshardGroups = (cluster: Maybe<GetClusterCluster>): GetClusterVshardGroup[] =>
  compact(cluster?.vshard_groups ?? []);

// get-cluster
export const cluster = (data: GetCluster): GetClusterCluster | undefined => data?.cluster ?? undefined;

export const clusterSelf = (data: GetCluster): GetClusterClusterSelf | undefined =>
  cluster(data)?.clusterSelf ?? undefined;

export const clusterSelfUri = (data: GetCluster): string | undefined => clusterSelf(data)?.uri ?? undefined;

export const knownRoles = (data: GetCluster): GetClusterRole[] => compact(data?.cluster?.knownRoles ?? []);

export const vshardGroups = (data: GetCluster): GetClusterVshardGroup[] => clusterVshardGroups(data?.cluster);

export const vshardGroupsNames = (data: GetCluster): string[] => vshardGroups(data).map(({ name }) => name);

export const authParams = (data: GetCluster): Partial<GetClusterAuthParams> => data?.cluster?.authParams ?? {};

export const failoverParams = (data: GetCluster): GetClusterFailoverParams | undefined =>
  data?.cluster?.failover_params ?? undefined;

export const failoverParamsMode = (data: GetCluster): string | undefined => failoverParams(data)?.mode;

export const rebalancerMode = (data: GetCluster): { name: string; rebalancer_mode: string } | undefined =>
  data?.cluster?.vshard_groups[0]
    ? {
        name: data.cluster.vshard_groups[0].name,
        rebalancer_mode: data.cluster.vshard_groups[0].rebalancer_mode,
      }
    : undefined;

export const isConfigured = (data: GetCluster): boolean => isClusterSelfConfigured(clusterSelf(data));

export const knownRolesNames = (data: GetCluster): KnownRolesNamesResult => {
  return knownRoles(data).reduce(
    (acc, { name, implies_router, implies_storage }) => {
      if (implies_router) acc.router.push(name);
      if (implies_storage) acc.storage.push(name);
      return acc;
    },
    { router: [], storage: [] } as KnownRolesNamesResult
  );
};

const isRoleAvailableSelectorCreator =
  (type: 'storage' | 'router') =>
  (data: GetCluster): boolean =>
    knownRolesNames(data)[type].length > 0;

const isRoleEnabledSelectorCreator =
  (type: 'storage' | 'router') =>
  (serverList: ServerList, cluster: GetCluster): boolean => {
    const { replicasetList } = serverList || {};
    if (replicasetList) {
      const names = knownRolesNames(cluster);
      for (let i = 0; i < replicasetList.length; i++) {
        const { roles } = replicasetList[i] ?? {};
        if (roles && roles.some((role) => names[type].includes(role))) {
          return true;
        }
      }
    }

    return false;
  };

export const isStorageEnabled = isRoleEnabledSelectorCreator('storage');

export const isRouterEnabled = isRoleEnabledSelectorCreator('router');

export const isStorageAvailable = isRoleAvailableSelectorCreator('storage');

export const isRouterAvailable = isRoleAvailableSelectorCreator('router');

export const isVshardAvailable = (data: GetCluster): boolean => isStorageAvailable(data) && isRouterAvailable(data);

export const isVshardBootstrapped = (data: GetCluster) => Boolean(cluster(data)?.vshard_groups?.[0]?.bootstrapped);

export const canBootstrapVshard = (serverList: ServerList, cluster: GetCluster): boolean =>
  isRouterEnabled(serverList, cluster) && isStorageEnabled(serverList, cluster);

// server-list
export const serverList = (data: ServerList): ServerListServer[] => compact(data?.serverList ?? []);

export const serverStat = (data: ServerList): ServerListServerStat[] => compact(data?.serverStat ?? []);

export const issues = (data: ServerList): ServerListClusterIssue[] => compact(data?.cluster?.issues ?? []);

export const zones = (data: ServerList): string[] =>
  pipe(
    serverList,
    map(({ zone }) => zone),
    compact,
    uniq
  )(data);

export const issuesFilteredByInstanceUuid = (data: ServerList, uuid: Maybe<string>): ServerListClusterIssue[] =>
  uuid ? issues(data).filter(({ instance_uuid }) => instance_uuid === uuid) : [];

export const replicasetList = (data: ServerList): ServerListReplicaset[] => compact(data?.replicasetList ?? []);

export const serverGetByUuid = (data: ServerList, uuid: Maybe<string>): ServerListServer | undefined =>
  uuid ? serverList(data).find((server) => server.uuid === uuid) : undefined;

export const serverLabelsGetByUuid = (data: ServerList, uuid: string): Array<InputMaybe<LabelInput>> =>
  data?.serverList ? serverList(data).find((server) => server.uuid === uuid)?.labels ?? [] : [];

export const serverGetByUri = (data: ServerList, uri: Maybe<string>): ServerListServer | undefined =>
  uri ? serverList(data).find((server) => server.uri === uri) : undefined;

export const replicasetGetByUuid = (data: ServerList, uuid: Maybe<string>): ServerListReplicaset | undefined =>
  uuid ? replicasetList(data).find((replicaset) => replicaset.uuid === uuid) : undefined;

export const isMaster = (replicaset: ServerListReplicaset | undefined, uuid: Maybe<string>): boolean =>
  !!uuid && uuid === replicaset?.master.uuid;

export const isActiveMaster = (replicaset: ServerListReplicaset | undefined, uuid: Maybe<string>): boolean =>
  !!uuid && uuid === replicaset?.active_master.uuid;

export const unConfiguredServerList = (data: ServerList): ServerListServer[] =>
  serverList(data).filter((item) => !item?.replicaset);

export const sortUnConfiguredServerList = (
  servers: ServerListServer[],
  clusterSelf?: Maybe<GetClusterClusterSelf>
): ServerListServer[] => {
  if (isClusterSelfConfigured(clusterSelf)) {
    return [...servers];
  }

  return [...servers].sort((a, b) => (a.uri === clusterSelf?.uri ? -1 : b.uri === clusterSelf?.uri ? 1 : 0));
};

export function sortReplicasetList(items: ServerListReplicasetSearchable[]): ServerListReplicasetSearchable[];
export function sortReplicasetList(items: ServerListReplicaset[]): ServerListReplicaset[];
export function sortReplicasetList(
  items: (ServerListReplicaset | ServerListReplicasetSearchable)[]
): (ServerListReplicaset | ServerListReplicasetSearchable)[] {
  return [...items].sort((a, b) => {
    let aValue = a.alias || '';
    let bValue = b.alias || '';

    if (aValue === bValue) {
      aValue = a.servers[0]?.alias || '';
      bValue = b.servers[0]?.alias || '';
    }

    if (aValue === bValue) {
      aValue = a.uuid;
      bValue = b.uuid;
    }

    return aValue < bValue ? -1 : 1;
  });
}

// counts
export const serverListCounts = (data: ServerList) =>
  serverList(data).reduce(
    (acc, item) => {
      if (item) {
        acc.total++;
        item.replicaset ? acc.configured++ : acc.unconfigured++;
      }

      return acc;
    },
    { configured: 0, total: 0, unconfigured: 0 }
  );

export const replicasetCounts = (data: ServerList) =>
  replicasetList(data).reduce(
    (acc, replicaset) => {
      if (replicaset) {
        acc.total.replicasets++;
        if (replicaset.status !== 'healthy') {
          acc.unhealthy.replicasets++;
        } else {
          acc.healthy.replicasets++;
        }

        replicaset.servers.forEach((instance) => {
          acc.total.instances++;
          if (instance.status !== 'healthy') {
            acc.unhealthy.instances++;
          } else {
            acc.healthy.instances++;
          }
        });
      }

      return acc;
    },
    {
      total: { replicasets: 0, instances: 0 },
      healthy: { replicasets: 0, instances: 0 },
      unhealthy: { replicasets: 0, instances: 0 },
    }
  );

// search
const replicasetServerSearchItems = ({ uri, alias, status, boxinfo }: ServerListReplicasetServer): string[] => {
  return [uri, alias ?? '', `status:${status}`, boxinfo?.general.ro ? 'is:follower' : 'is:leader'].filter(Boolean);
};

const replicasetSearchItems = ({ alias, roles, servers }: ServerListReplicaset): string[] => {
  const tokens = servers.reduce((acc, item) => {
    replicasetServerSearchItems(item).forEach((value) => {
      acc.push(value);
    });

    return acc;
  }, [] as string[]);

  servers;

  return [alias, ...(roles ?? []), ...tokens].filter(Boolean);
};

const searchStringItemsToString = (items: string[]): string => {
  return items.filter(Boolean).join(' ').toLowerCase();
};

export const replicasetListSearchable = (items: ServerListReplicaset[]): ServerListReplicasetSearchable[] => {
  return items.map((replicaset) => {
    const servers = replicaset.servers.map((server: ServerListReplicasetServer) => ({
      ...server,
      meta: {
        searchString: searchStringItemsToString(replicasetServerSearchItems(server)),
      },
    }));

    return {
      ...replicaset,
      servers,
      meta: {
        searchString: searchStringItemsToString(replicasetSearchItems(replicaset)),
      },
    };
  });
};
