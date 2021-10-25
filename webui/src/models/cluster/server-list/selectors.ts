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
  ServerListReplicaset,
  ServerListReplicasetSearchable,
  ServerListReplicasetServer,
  ServerListServer,
  ServerListServerClusterIssue,
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

// get-cluster
export const cluster = (data: GetCluster): GetClusterCluster | undefined => data?.cluster ?? undefined;

export const clusterSelf = (data: GetCluster): GetClusterClusterSelf | undefined =>
  cluster(data)?.clusterSelf ?? undefined;

export const clusterSelfUri = (data: GetCluster): string | undefined => clusterSelf(data)?.uri ?? undefined;

export const knownRoles = (data: GetCluster): GetClusterRole[] => compact(data?.cluster?.knownRoles ?? []);

export const vshardGroups = (data: GetCluster): GetClusterVshardGroup[] => compact(data?.cluster?.vshard_groups ?? []);

export const vshardGroupsNames = (data: GetCluster): string[] => vshardGroups(data).map(({ name }) => name);

export const authParams = (data: GetCluster): Partial<GetClusterAuthParams> => data?.cluster?.authParams ?? {};

export const failoverParams = (data: GetCluster): GetClusterFailoverParams | undefined =>
  data?.cluster?.failover_params ?? undefined;

export const failoverParamsMode = (data: GetCluster): string | undefined => failoverParams(data)?.mode;

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

export const isBootstrapped = (data: GetCluster) => Boolean(cluster(data)?.vshard_groups?.[0]?.bootstrapped);

export const canBootstrapVshard = (serverList: ServerList, cluster: GetCluster): boolean =>
  isRouterEnabled(serverList, cluster) && isStorageEnabled(serverList, cluster);

// server-list
export const serverList = (data: ServerList): ServerListServer[] => compact(data?.serverList ?? []);

export const serverStat = (data: ServerList): ServerListServerStat[] => compact(data?.serverStat ?? []);

export const issues = (data: ServerList): ServerListServerClusterIssue[] => compact(data?.cluster?.issues ?? []);

export const zones = (data: ServerList): string[] =>
  pipe(
    serverList,
    map(({ zone }) => zone),
    compact,
    uniq
  )(data);

export const issuesFilteredByInstanceUuid = (data: ServerList, uuid: Maybe<string>): ServerListServerClusterIssue[] =>
  uuid ? issues(data).filter(({ instance_uuid }) => instance_uuid === uuid) : [];

export const replicasetList = (data: ServerList): ServerListReplicaset[] => compact(data?.replicasetList ?? []);

export const serverGetByUuid = (data: ServerList, uuid: Maybe<string>): ServerListServer | undefined =>
  uuid ? serverList(data).find((server) => server.uuid === uuid) : undefined;

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

export const sortReplicasetList = (items: ServerListReplicaset[]): ServerListReplicaset[] =>
  [...items].sort((a, b) => {
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
    (acc, item) => {
      if (item) {
        acc.total++;
        if (item.status !== 'healthy') {
          acc.unhealthy++;
        }
      }

      return acc;
    },
    { total: 0, unhealthy: 0 }
  );

// search
const replicasetServerSearchItems = ({ uri, alias }: ServerListReplicasetServer): string[] => {
  return [uri, alias ?? ''].filter(Boolean);
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
