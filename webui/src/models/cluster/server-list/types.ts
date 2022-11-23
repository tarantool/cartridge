import type { GetClusterQuery, ServerListQuery } from 'src/generated/graphql-typing-ts';
import type { Maybe } from 'src/models';

export type ServerList = Maybe<ServerListQuery>;
export type ServerListServer = NonNullable<NonNullable<NonNullable<ServerList>['serverList']>[number]>;
export type ServerListCluster = NonNullable<NonNullable<ServerList>['cluster']>;
export type ServerListClusterIssue = NonNullable<ServerListCluster['issues']>[number];
export type ServerListReplicaset = NonNullable<NonNullable<NonNullable<ServerList>['replicasetList']>[number]>;
export type ServerListReplicasetServer = NonNullable<ServerListReplicaset['servers']>[number];
export type ServerListServerStat = NonNullable<NonNullable<NonNullable<ServerList>['serverStat']>[number]>;
export type ServerListServerStatStatistics = NonNullable<ServerListServerStat['statistics']>;
export type ServerListClusterRole = NonNullable<NonNullable<ServerListCluster['known_roles']>[number]>;

export type ServerListReplicasetServerSearchable = ServerListReplicasetServer & {
  meta?: {
    searchString: string;
    filterMatching?: boolean;
  };
};

export type ServerListReplicasetSearchable = Omit<ServerListReplicaset, 'servers'> & {
  servers: ServerListReplicasetServerSearchable[];
  meta?: {
    searchString: string;
    matchingServersCount?: number;
    totalServersCount?: number;
  };
};

export type GetCluster = Maybe<GetClusterQuery>;
export type GetClusterCluster = NonNullable<NonNullable<GetCluster>['cluster']>;
export type GetClusterAuthParams = NonNullable<GetClusterCluster['authParams']>;
export type GetClusterFailoverParams = NonNullable<GetClusterCluster['failover_params']>;
export type GetClusterClusterSelf = NonNullable<GetClusterCluster['clusterSelf']>;
export type GetClusterRole = NonNullable<NonNullable<GetClusterCluster['knownRoles']>[number]>;
export type GetClusterVshardGroup = NonNullable<NonNullable<GetClusterCluster['vshard_groups']>[number]>;
export type GetClusterCompressionInfo = NonNullable<GetClusterCluster>['cluster_compression']['compression_info'];

export interface PromoteServerToLeaderEventPayload {
  replicasetUuid: string;
  instanceUuid: string;
  force?: boolean;
}

export interface DisableOrEnableServerEventPayload {
  uuid: string;
  disable: boolean;
}

export interface SetElectableServerEventPayload {
  uuid: string;
  electable: boolean;
}

export interface KnownRolesNamesResult {
  router: string[];
  storage: string[];
}

export interface CompressionSuggestion {
  type: 'compression';
  meta: {
    instanceId: string;
    spaceName: string;
    fields: Array<{ name: string; compressionPercentage: number }>;
  };
}

export type Suggestion = CompressionSuggestion;
