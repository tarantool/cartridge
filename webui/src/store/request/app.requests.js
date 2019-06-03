import graphql from 'src/api/graphql';
import {getClusterQuery} from "./queries.graphql";


export async function getClusterSelf() {
  const response = await graphql.fetch(getClusterQuery);

  const {
    clusterSelf,
    failover,
    knownRoles,
    can_bootstrap_vshard,
    vshard_bucket_count,
    authParams
  } = response.cluster;

  return {
    clusterSelf: {
      ...clusterSelf,
      uuid: clusterSelf.uuid || null,
      configured: !!clusterSelf.uuid,
      knownRoles,
      can_bootstrap_vshard,
      vshard_bucket_count,
    },
    authParams,
    failover
  };
}
