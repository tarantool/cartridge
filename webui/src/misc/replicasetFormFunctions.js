// @flow
import { uniq } from 'ramda';

import type { Replicaset, Role } from 'src/generated/graphql-typing';
import store from 'src/store/instance';
import { selectVshardRolesNames } from 'src/store/selectors/clusterPage';

export const getDependenciesString = (dependencies: ?(string[])) => {
  if (!dependencies || !dependencies.length) return '';

  return dependencies.length > 3
    ? ` (+ ${dependencies.slice(0, 2).join(', ')}, ${dependencies.length - 2} more)`
    : ` (+ ${dependencies.join(', ')})`;
};

export const getRolesDependencies = (activeRoles: string[], rolesOptions?: ?(Role[])) => {
  const result = [];
  rolesOptions &&
    rolesOptions.forEach(({ name, dependencies }) => {
      if (activeRoles.includes(name) && dependencies) {
        result.push(...dependencies);
      }
    });
  return uniq(result);
};

export const isVShardGroupInputDisabled = (roles?: string[], replicaset: ?Replicaset): boolean => {
  const storageRolesNames = selectVshardRolesNames(store.getState()).storage;
  return !(roles || []).some((role) => storageRolesNames.includes(role)) || !!(replicaset && replicaset.vshard_group);
};

type ValidateFormArgs = {
  alias?: string,
  roles: string[],
  vshard_group?: string,
  weight?: string,
};

export const validateForm = ({ alias, roles, vshard_group, weight }: ValidateFormArgs) => {
  const errors = {};
  const { storage: storageRolesNames } = selectVshardRolesNames(store.getState());

  if (typeof weight === 'string') {
    const numericWeight = Number(weight);

    if (isNaN(numericWeight) || numericWeight < 0) {
      errors.weight = 'Field accepts number, ex: 0, 1, 2.43...';
    }
  }

  if (alias && alias.length > 63) {
    errors.alias = 'Alias must not exceed 63 character';
  } else if (alias && alias.length && !/^[a-zA-Z0-9-_.]+$/.test(alias)) {
    errors.alias = 'Allowed symbols are: a-z, A-Z, 0-9, _ . -';
  }

  if ((roles || []).some((role) => storageRolesNames.includes(role)) && !vshard_group) {
    errors.vshard_group = `Group is required for ${storageRolesNames.join(' or ')} role`;
  }

  return errors;
};
