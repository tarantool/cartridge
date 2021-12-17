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
}

const ReplicasetListBuckets = ({ total, count }: ReplicasetListBucketsProps) => {
  if (isMaybe(count)) {
    return null;
  }

  return (
    <Container
      className={styles.root}
      tooltipContent={`Total bucket: ${isMaybe(total) ? '-' : total}`}
      data-component="ReplicasetListBuckets"
      data-value-total={total}
      data-value-count={count}
    >
      <IconBucket className={cx(styles.icon, 'meta-test__bucketIcon')} />
      <span className={styles.label}>{count}</span>
    </Container>
  );
};

export default memo(ReplicasetListBuckets);
