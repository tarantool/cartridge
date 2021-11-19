import React from 'react';
import { cx } from '@emotion/css';
import { Text } from '@tarantool.io/ui-kit';

import type { Maybe } from 'src/models';

import { styles } from './ReplicasetRoles.styles';

export interface ReplicasetRolesProps {
  className?: string;
  roles?: Maybe<string[]>;
}

const ReplicasetRoles = ({ className, roles }: ReplicasetRolesProps) =>
  roles && roles.length ? (
    <Text className={cx(styles.roles, className)} tag="div">
      <b className={styles.rolesHeading}>Role:</b>
      {roles.join(' | ')}
    </Text>
  ) : (
    <Text className={cx(styles.roles, className)} tag="div">
      No roles
    </Text>
  );

export default ReplicasetRoles;
