/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { ReactNode, memo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { withTooltip } from '@tarantool.io/ui-kit';

import { styles } from './ReplicasetListTag.styles';

const Container = withTooltip('div');

export interface ReplicasetListTagProps {
  children: ReactNode;
  title?: string;
  className?: string;
}

const ReplicasetListTag = ({ className, children, title }: ReplicasetListTagProps) => {
  return (
    <Container className={cx(styles.root, className)} tooltipContent={title}>
      {children}
    </Container>
  );
};

export default memo(ReplicasetListTag);
