// @flow
import * as R from 'ramda';
import {
  createSelector,
  createSelectorCreator,
  defaultMemoize
} from 'reselect';
import isEqual from 'lodash/isEqual';
import type { State } from 'src/store/rootReducer';
import type { ServerStatWithUUID } from 'src/store/reducers/clusterPage.reducer';
import type { Replicaset, Server } from 'src/generated/graphql-typing';
import {
  calculateMemoryFragmentationLevel,
  type FragmentationLevel,
  type MemoryUsageRatios
} from 'src/misc/memoryStatistics';


const prepareReplicasetList = (
  replicasetList: Replicaset[],
  serverStat: ?ServerStatWithUUID[]
): Replicaset[] => replicasetList.map(replicaset => {
  const servers = replicaset.servers.map(server => {
    const stat = (serverStat || []).find(stat => stat.uuid === server.uuid);

    return {
      ...server,
      statistics: stat ? stat.statistics : null
    };
  });

  return {
    ...replicaset,
    servers
  };
});

const selectServerStat = (state: State): ?ServerStatWithUUID[] => state.clusterPage.serverStat;

const selectReplicasetList = (state: State): ?Replicaset[] => state.clusterPage.replicasetList;

const selectServerList = (state: State): ?Server[] => state.clusterPage.serverList;

export const selectServerByUri = (state: State, uri: string): ?Server => {
  if (Array.isArray(state.clusterPage.serverList))
    return state.clusterPage.serverList.find(x => x.uri === uri)
  return null
}

export const selectReplicasetListWithStat: (s: State) => Replicaset[] = createSelector(
  [selectReplicasetList, selectServerStat],
  (replicasetList: ?Replicaset[], serverStat: ?ServerStatWithUUID[]): Replicaset[] => (
    replicasetList ? prepareReplicasetList(replicasetList, serverStat) : []
  )
);

type IsRolePresentSelector = (s: State) => boolean;

export const isRolePresentSelectorCreator = (roleName: string): IsRolePresentSelector => createSelector(
  selectReplicasetList,
  (replicasetList: ?Replicaset[]): boolean => {
    if (replicasetList) {
      for (let i = 0; i < replicasetList.length; i++) {
        const { roles } = replicasetList[i];
        if (roles && roles.includes(roleName)) {
          return true;
        }
      }
    }

    return false;
  }
);

type SearchableServer = {
  ...$Exact<Server>,
  searchString: string
};

type WithSearchStringAndServersType = {
  servers: SearchableServer[],
  searchString: string
}

type SearchableReplicaset = {
  ...$Exact<Replicaset>,
  ...$Exact<WithSearchStringAndServersType>
};

type SearchTokenObject = {
  value: string,
  asSubstring: boolean,
  not: boolean
};

type TokensByPrefix = {
  all: Array<string>,
  [prefix: string]: Array<SearchTokenObject>
};

export const selectSearchableReplicasetList: (s: State) => SearchableReplicaset[] = createSelector(
  selectReplicasetListWithStat,
  (replicasetList: Replicaset[]): SearchableReplicaset[] => {
    return replicasetList.map(({ servers, ...replicaSet }) => {
      let replicaSetSearchIndex = [replicaSet.alias, ...(replicaSet.roles || [])];

      const searchableServers: SearchableServer[] = servers.map(server => {
        const serverSearchIndex = [server.uri, (server.alias || '')];

        if (replicaSet.status === 'healthy') {
          serverSearchIndex.push('healthy');
        }

        (server.labels || []).forEach(label => {
          if (label) {
            serverSearchIndex.push(`${label.name}:`, label.value);
          }
        });

        replicaSetSearchIndex.push(...serverSearchIndex);

        const searchableServer: SearchableServer = {
          ...server,
          searchString: serverSearchIndex.join(' ').toLowerCase()
        };

        return searchableServer;
      });

      return {
        ...replicaSet,
        searchString: replicaSetSearchIndex.join(' ').toLowerCase(),
        servers: searchableServers
      };
    });
  });

export const getFilterData = (filterQuery: string): Object => {

  // @TODO respect quotes (") and backslashes (\)
  let tokenizedQuery = filterQuery.toLowerCase().split(' ').map(x => x.trim()).filter(x => !!x);

  const prefixes = {
    replicaSet: [
      'uuid',
      'roles',
      'alias',
      'status'
    ],
    server: [
      'uri',
      'uuid',
      'alias',
      'labels',
      'status'
    ]
  };

  const SEPARATOR = ':';
  const tokensByPrefix: TokensByPrefix = tokenizedQuery.reduce((acc, tokenString) => {
    let prefix;
    let value;

    const separatorIndex = tokenString.indexOf(SEPARATOR);
    if (separatorIndex === -1) {
      prefix = 'all';
      value = tokenString;
    } else {
      // Example: For `status*:healthy`, prefix='status', modifier='*'
      const prefixAndModifier = tokenString.substring(0, separatorIndex);
      value = tokenString.substring(separatorIndex + 1);

      if (value === '') {
        // pass by if empty value
        return acc;
      }

      const modifier = prefixAndModifier.slice(-1);
      if (modifier === '!' || modifier === '*') {
        prefix = prefixAndModifier.slice(0, -1);
      } else {
        prefix = prefixAndModifier;
      }
      const tokenObject: SearchTokenObject = {
        value,
        asSubstring: modifier === '*',
        not: modifier === '!'
      };

      // Some mapping
      // @TODO eliminate hardcode
      if (prefix === 'role') {
        prefix = 'roles';
      }

      // treat unknown prefixes as just part of the value
      if (
        prefixes.replicaSet.indexOf(prefix) === -1
        &&
        prefixes.server.indexOf(prefix) === -1
      ) {
        prefix = 'all';
        value = tokenString;
      } else {
        value = tokenObject;
      }
    }

    // (Flow don't understand more general code with "?:")
    if (prefix === 'all') {
      acc['all'].push(tokenString);
    } else {
      acc[prefix] = acc[prefix] || ([]: SearchTokenObject[]);
      acc[prefix].push(((value: any): SearchTokenObject));
    }

    return acc;
  }, ({ all: [] }: TokensByPrefix));

  return {
    tokensByPrefix,
    tokenizedQuery
  };
}

export const filterReplicasetList = (state: State, filterQuery: string): Replicaset[] => {
  const { tokensByPrefix, tokenizedQuery } = getFilterData(filterQuery);

  const filterByTokens = R.filter(
    R.allPass(
      tokensByPrefix.all.map(token => r => r.searchString.includes(token) || r.uuid.startsWith(token))
    )
  );

  const filterServerByTokens = R.allPass(
    tokenizedQuery.map(token => searchString => searchString.includes(token))
  );

  const filteredReplicasetList = filterByTokens(selectSearchableReplicasetList(state));

  const isInProperty = (property, searchSrting, asSubstring = false) => {
    if (Array.isArray(property)) {
      if (asSubstring) {
        return property.some(propValue => {
          // deny if not string
          return (typeof propValue === 'string') && propValue.indexOf(searchSrting) !== -1
        })
      }
      return property.indexOf(searchSrting) !== -1;
    } else {
      if (asSubstring) {
        // deny if not string
        return (typeof property === 'string') && property.indexOf(searchSrting) !== -1
      }
      return property === searchSrting;
    }
  };

  const filterByProperty = (list, property, tokensForProperty: SearchTokenObject[]) => list.filter(item => (
    tokensForProperty.every(token => {
      if (token.not) {
        return !isInProperty(item[property], token.value);
      }
      if (token.asSubstring) {
        return isInProperty(item[property], token.value, true);
      }
      return isInProperty(item[property], token.value);
    })
  ));

  let filteredByProperties = filteredReplicasetList;
  Object.entries(tokensByPrefix).forEach(([property, tokensForProperty]) => {
    if (property !== 'all') {
      filteredByProperties = filterByProperty(
        filteredByProperties,
        property,
        ((tokensForProperty: any): SearchTokenObject[])
      );
    }
  });

  const preparedReplicasetList = filteredByProperties.map(replicaSet => {
    let matchingServersCount = 0;

    const servers = replicaSet.servers.map(server => {
      const filterMatching = filterServerByTokens(server.searchString);

      if (filterMatching) {
        matchingServersCount++;
      }

      return {
        ...server,
        filterMatching
      }
    });

    return {
      ...replicaSet,
      matchingServersCount,
      servers
    }
  });
  return preparedReplicasetList;
};

export const filterReplicasetListSelector = (state: State): Replicaset[] => {
  const filterQuery = state.clusterPage.replicasetFilter;
  return filterReplicasetList(state, filterQuery);
};

export const filterModalReplicasetListSelector = (state: State): Replicaset[] => {
  const filterQuery = state.clusterPage.modalReplicasetFilter;
  return filterReplicasetList(state, filterQuery);
};

export type ServerCounts = {
  total: number,
  configured: number,
  unconfigured: number,
};

export const getServerCounts: (s: State) => ServerCounts = createSelector(
  selectServerList,
  (serverList: ?Server[]): ServerCounts => (serverList || []).reduce(
    (acc, server) => {
      acc.total++;
      server.replicaset ? acc.configured++ : acc.unconfigured++;
      return acc;
    },
    { configured: 0, total: 0, unconfigured: 0 }
  )
);

export type ReplicasetCounts = {
  total: number,
  unhealthy: number,
};

export const getReplicasetCounts: (s: State) => ReplicasetCounts = createSelector(
  selectReplicasetList,
  (replicasetList: ?Replicaset[]): ReplicasetCounts => {
    return (replicasetList || []).reduce(
      (acc, replicaset) => {
        acc.total++;
        replicaset.status !== 'healthy' && acc.unhealthy++;
        return acc;
      },
      { total: 0, unhealthy: 0 }
    )
  }
);

export const getSectionsNames = (state: State): Array<string> => Object.keys(state.clusterInstancePage.boxinfo || {});

export const isBootstrapped = (state: State) => (
  R.path(['app', 'clusterSelf', 'vshard_groups', '0', 'bootstrapped'], state) || false
)


const createDeepEqualSelector = createSelectorCreator(defaultMemoize, isEqual);

export const getMemoryFragmentationLevel
  : (statistics: MemoryUsageRatios) => FragmentationLevel = createDeepEqualSelector(
    [
      statistics => statistics
    ],
    calculateMemoryFragmentationLevel
  );
