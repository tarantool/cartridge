/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { ProgressBar, Tooltip } from '@tarantool.io/ui-kit';

import { Maybe, app } from 'src/models';

import MemoryIcon from '../MemoryIcon';

import { styles } from './ReplicasetListMemStat.styles';

const { getReadableBytes } = app.utils;

export interface ReplicasetListStatistics {
  arenaUsed: number;
  quotaSize: number;
  quotaUsed: number;
  arenaSize: number;
  bucketsCount?: Maybe<number>;
  arena_used_ratio: string;
  quota_used_ratio: string;
  items_used_ratio: string;
}

export interface ReplicasetListMemStatProps {
  arena_used_ratio: string;
  quota_used_ratio: string;
  items_used_ratio: string;
  arenaUsed: number;
  quotaSize: number;
  quotaUsed: number;
  arenaSize: number;
  className?: string;
}

const ReplicasetListMemStat = ({
  arenaUsed,
  quotaSize,
  quotaUsed,
  arenaSize,
  arena_used_ratio,
  quota_used_ratio,
  items_used_ratio,
  className,
}: ReplicasetListMemStatProps) => {
  const [usageText, percentage] = useMemo((): [string, number] => {
    const used = arenaUsed + quotaUsed - arenaSize;
    return [
      `Memory usage: ${getReadableBytes(used)} / ${getReadableBytes(quotaSize)}`,
      Math.max(1, (used / quotaSize) * 100),
    ];
  }, [arenaUsed, quotaUsed, arenaSize, quotaSize]);

  return (
    <div
      className={cx(styles.root, className)}
      data-component="ReplicasetListMemStat"
      data-value-percentage={percentage}
      data-value-tooltip={usageText}
    >
      <MemoryIcon {...{ arena_used_ratio, quota_used_ratio, items_used_ratio }} />
      <Tooltip content={usageText}>
        <ProgressBar className={styles.progress} percents={percentage} statusColors />
      </Tooltip>
    </div>
  );
};

export default memo(ReplicasetListMemStat);
