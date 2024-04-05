// @flow
import graphql from 'src/api/graphql';
import rest from 'src/api/rest';
import { getApiEndpoint } from 'src/apiEndpoints';

import { getClusterQuery } from './queries.graphql';

export function getMigrationsStates() {
  return rest.get(getApiEndpoint('MIGRATIONS_API_ENDPOINT') + '/applied');
}

export function migrationsUp() {
  return rest.post(getApiEndpoint('MIGRATIONS_API_ENDPOINT') + '/up');
}

export function migrationsMove() {
  return rest.post(getApiEndpoint('MIGRATIONS_API_ENDPOINT') + '/move_migrations_state');
}

export async function getMigrationsEnabled() {
  try {
    await getMigrationsStates();
    return true;
  } catch (error) {
    void error;
  }

  return false;
}

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
