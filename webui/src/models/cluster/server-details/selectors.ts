import type { InstanceDataQuery } from 'src/generated/graphql-typing-ts';
import type { Maybe } from 'src/models';

import type { InstanceDataQueryDescription, ServerDetails, ServerDetailsDescriptionsNames } from './types';

export const sectionAndDescriptionsBySectionName = (
  serverDetails: Maybe<ServerDetails>,
  sectionName: ServerDetailsDescriptionsNames
) => ({
  descriptions: serverDetails?.descriptions[sectionName],
  section: serverDetails?.server?.boxinfo?.[sectionName],
});

const descriptionsByName = (value: Maybe<InstanceDataQueryDescription>): Record<string, string | undefined> =>
  value?.fields?.reduce((acc, item) => {
    acc[item.name] = item.description ?? undefined;
    return acc;
  }, {} as Record<string, string | undefined>) ?? {};

export const mapServerDetailsToDescriptions = ({
  descriptionCartridge,
  descriptionGeneral,
  descriptionNetwork,
  descriptionReplication,
  descriptionStorage,
  descriptionMembership,
  descriptionVshardRouter,
  descriptionVshardStorage,
}: InstanceDataQuery) => {
  return {
    cartridge: descriptionsByName(descriptionCartridge),
    general: descriptionsByName(descriptionGeneral),
    network: descriptionsByName(descriptionNetwork),
    replication: descriptionsByName(descriptionReplication),
    storage: descriptionsByName(descriptionStorage),
    membership: descriptionsByName(descriptionMembership),
    vshard_router: descriptionsByName(descriptionVshardRouter),
    vshard_storage: descriptionsByName(descriptionVshardStorage),
  };
};
