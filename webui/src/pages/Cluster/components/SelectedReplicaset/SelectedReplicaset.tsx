/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { HealthStatus, Text } from '@tarantool.io/ui-kit';

import type { Replicaset } from 'src/generated/graphql-typing';

import { styles } from './SelectedReplicaset.styles';

export interface SelectedReplicasetProps {
  className?: string;
  replicaset?: Replicaset;
}

const SelectedReplicaset = ({ className, replicaset }: SelectedReplicasetProps) => {
  const { alias, status, uuid } = replicaset || {};

  return (
    <div className={cx(styles.replicaset, className)}>
      <div className={styles.headingWrap}>
        <Text className={styles.alias} variant="h3">
          {alias || uuid}
        </Text>
        <HealthStatus className={styles.status} status={status} />
      </div>
      <Text className={styles.uuid} variant="p" tag="span">{`uuid: ${uuid}`}</Text>
    </div>
  );
};

export default SelectedReplicaset;
