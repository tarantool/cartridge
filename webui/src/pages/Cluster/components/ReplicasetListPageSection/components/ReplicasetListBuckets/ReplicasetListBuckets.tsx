/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { IconBucket, withTooltip } from '@tarantool.io/ui-kit';

import { Maybe, app } from 'src/models';

import { styles } from './ReplicasetListBuckets.styles';

const { isMaybe } = app.utils;

const Container = withTooltip('div');

export interface ReplicasetListBucketsProps {
  total?: Maybe<number>;
  count?: Maybe<number>;
  className?: string;
}

const ReplicasetListBuckets = ({ total, count, className }: ReplicasetListBucketsProps) => {
  if (isMaybe(count)) {
    return null;
  }

  return (
    <Container className={cx(styles.root, className)} tooltipContent={`Total bucket: ${isMaybe(total) ? '-' : total}`}>
      <IconBucket className={styles.icon} />
      <span className={styles.label}>{count}</span>
    </Container>
  );
};

export default memo(ReplicasetListBuckets);
