/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { css } from '@emotion/css';
// @ts-ignore
import { IconChip, IconChipDanger, IconChipWarning, Tooltip } from '@tarantool.io/ui-kit';

import { MemoryUsageRatios, calculateMemoryFragmentationLevel } from 'src/misc/memoryStatistics';

export const styles = {
  iconMargin: css`
    margin-right: 4px;
  `,
};

export interface MemoryIconProps {
  arena_used_ratio: string;
  quota_used_ratio: string;
  items_used_ratio: string;
}

const MemoryIcon = (props: MemoryUsageRatios) => {
  const fragmentationLevel = calculateMemoryFragmentationLevel(props);
  switch (fragmentationLevel) {
    case 'high':
      return (
        <Tooltip tag="span" content="Running out of memory">
          <IconChipDanger className={styles.iconMargin} />
        </Tooltip>
      );
    case 'medium':
      return (
        <Tooltip tag="span" content="Memory is highly fragmented">
          <IconChipWarning className={styles.iconMargin} />
        </Tooltip>
      );
  }

  return <IconChip className={styles.iconMargin} />;
};

export default memo(MemoryIcon);
