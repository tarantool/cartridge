// @flow
import graphql from 'src/api/graphql';

import { getClusterQuery } from './queries.graphql';

export async function getClusterSelf() {
  const response = await graphql.fetch(getClusterQuery);

  const {
    clusterSelf,
    failover_params,
    knownRoles,
    can_bootstrap_vshard,
    vshard_bucket_count,
    vshard_groups,
    authParams,
    MenuBlacklist,
  } = response.cluster;

  return {
    clusterSelf: {
      ...clusterSelf,
      uuid: clusterSelf.uuid || null,
      configured: !!clusterSelf.uuid,
      knownRoles,
      can_bootstrap_vshard,
      vshard_bucket_count,
      vshard_groups,
    },
    MenuBlacklist,
    authParams,
    failover_params,
  };
}
