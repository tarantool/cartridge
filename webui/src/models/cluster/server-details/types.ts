import type { InstanceDataQuery } from 'src/generated/graphql-typing-ts';

export type InstanceDataQueryServer = NonNullable<NonNullable<NonNullable<InstanceDataQuery>['servers']>[number]>;
export type InstanceDataQueryDescription = NonNullable<NonNullable<InstanceDataQuery>['descriptionCartridge']>;

export type ServerDetailsDescriptionsNames =
  | 'general'
  | 'cartridge'
  | 'replication'
  | 'storage'
  | 'network'
  | 'membership'
  | 'vshard_router'
  | 'vshard_storage';

export type ServerDetailsDescriptions = Record<ServerDetailsDescriptionsNames, Record<string, string | undefined>>;

export type ServerDetails = {
  server: InstanceDataQueryServer;
  descriptions: ServerDetailsDescriptions;
};

export interface ClusterServerDetailsGateProps {
  uuid: string;
}
