import { allPass, filter } from 'ramda';

import type { ServerListReplicasetSearchable } from './types';

export type SearchTokenObject = {
  value: string;
  asSubstring: boolean;
  not: boolean;
};

export type TokensByPrefix = {
  all: string[];
  other: Record<string, SearchTokenObject[]>;
};

interface FilterData {
  tokensByPrefix: TokensByPrefix;
  tokenizedQuery: string[];
}

const TOKEN_SEPARATOR = ':';

const PREFIXES = {
  replicaSet: ['uuid', 'roles', 'alias', 'status'],
  server: ['uri', 'uuid', 'alias', 'labels', 'status'],
};

const getFilterData = (filterQuery: string): FilterData => {
  // TODO: respect quotes (") and backslashes (\)
  const tokenizedQuery = filterQuery
    .toLowerCase()
    .split(/[\s]+/)
    .map((x) => x.trim())
    .filter(Boolean);

  const tokensByPrefix = tokenizedQuery.reduce(
    (acc, tokenString) => {
      let prefix: 'all' | string = 'all';
      let value: string | SearchTokenObject = tokenString;

      const separatorIndex = tokenString.indexOf(TOKEN_SEPARATOR);
      if (separatorIndex > -1) {
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

        // Some mapping
        // @TODO eliminate hardcode
        if (prefix === 'role') {
          prefix = 'roles';
        }

        // treat unknown prefixes as just part of the value
        if (PREFIXES.replicaSet.indexOf(prefix) === -1 && PREFIXES.server.indexOf(prefix) === -1) {
          prefix = 'all';
          value = tokenString;
        } else {
          value = {
            value,
            asSubstring: modifier === '*',
            not: modifier === '!',
          };
        }
      }

      // (Flow don't understand more general code with "?:")
      if (prefix === 'all' && typeof value === 'string') {
        acc.all.push(value);
      } else if (prefix !== 'all' && typeof value !== 'string') {
        acc.other[prefix] = acc.other[prefix] || [];
        acc.other[prefix]?.push(value);
      }

      return acc;
    },
    { all: [], other: {} } as TokensByPrefix
  );

  return {
    tokensByPrefix,
    tokenizedQuery,
  };
};

const isInProperty = (property: string | string[], searchString: string, asSubstring = false): boolean => {
  if (Array.isArray(property)) {
    if (asSubstring) {
      return property.some((propValue) => {
        // deny if not string
        return typeof propValue === 'string' && propValue.indexOf(searchString) !== -1;
      });
    }

    return property.indexOf(searchString) !== -1;
  }

  if (asSubstring) {
    // deny if not string
    return typeof property === 'string' && property.indexOf(searchString) !== -1;
  }

  return property === searchString;
};

const filterByProperty = (
  list: ServerListReplicasetSearchable[],
  property: string,
  tokensForProperty: SearchTokenObject[]
): ServerListReplicasetSearchable[] =>
  list.filter((item) =>
    tokensForProperty.every((token) =>
      token.not
        ? !isInProperty(item[property], token.value)
        : isInProperty(item[property], token.value, token.asSubstring)
    )
  );

export const filterSearchableReplicasetList = (
  list: ServerListReplicasetSearchable[],
  filterQuery: string
): ServerListReplicasetSearchable[] => {
  if (!filterQuery) {
    return list;
  }

  const { tokensByPrefix, tokenizedQuery } = getFilterData(filterQuery);

  const filterByTokens: (list: ServerListReplicasetSearchable[]) => ServerListReplicasetSearchable[] = filter(
    allPass(
      tokensByPrefix.all.map(
        (token) => (r: ServerListReplicasetSearchable) =>
          (r.meta && r.meta.searchString.includes(token)) || r.uuid.startsWith(token)
      )
    )
  );

  const filterServerByTokens: (value: string) => boolean = allPass(
    tokenizedQuery.map((token: string) => (searchString: string) => searchString.includes(token))
  );

  const filteredByProperties = Object.entries(tokensByPrefix.other).reduce((acc, [property, tokensForProperty]) => {
    return filterByProperty(acc, property, tokensForProperty);
  }, filterByTokens(list));

  return filteredByProperties.map((replicaSet) => {
    let matchingServersCount = 0;
    console.log('replicaSet', replicaSet);

    const servers = replicaSet.servers.map((server) => {
      const filterMatching = filterServerByTokens(server.meta?.searchString ?? '');

      if (filterMatching) {
        matchingServersCount++;
      }

      return {
        ...server,
        meta: {
          searchString: server.meta?.searchString ?? '',
          filterMatching,
        },
      };
    });

    return {
      ...replicaSet,
      servers,
      meta: {
        searchString: replicaSet.meta?.searchString ?? '',
        matchingServersCount,
        totalServersCount: replicaSet.servers.length,
      },
    };
  });
};
