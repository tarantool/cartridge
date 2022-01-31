import React, { memo } from 'react';

import { CountHeader } from '../../../CountHeader';
import { CountHeaderWrapper } from '../../../CountHeaderWrapper';

import { styles } from './UnconfiguredInstancesListHeader.styles';

export interface UnconfiguredInstancesListHeaderProps {
  count: number;
}

const UnconfiguredInstancesListHeader = memo(({ count }: UnconfiguredInstancesListHeaderProps) => {
  return (
    <div className={styles.root} data-component="UnconfiguredInstancesListHeader">
      <CountHeaderWrapper>
        <CountHeader data-type="unconfigured-instances" counter={count} />
      </CountHeaderWrapper>
    </div>
  );
});

export default UnconfiguredInstancesListHeader;
