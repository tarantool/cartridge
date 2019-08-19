// @flow
// TODO: move to uikit
import React from 'react';
import Text from 'src/components/Text';
import { css, cx } from 'emotion';

const styles = {
  roles: css`
    display: flex;
    margin-top: 12px;
    opacity: 0.7;
  `,
  rolesHeading: css`
    margin-right: 4px;
    opacity: 0.85;
    font-weight: 1000;
  `
};

type ReplicasetRolesProps = {
  className?: string,
  roles?: string[]
}

const ReplicasetRoles = ({ className, roles }: ReplicasetRolesProps) => (
  roles && roles.length
    ? (
      <Text className={cx(styles.roles, className)} tag='div'>
        <b className={styles.rolesHeading}>Role:</b>
        {roles.join(' | ')}
      </Text>
    )
    : <Text className={cx(styles.roles, className)} tag='div'>No roles</Text>
);

export default ReplicasetRoles;
