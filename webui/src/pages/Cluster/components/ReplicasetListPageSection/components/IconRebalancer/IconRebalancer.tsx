/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { withTooltip } from '@tarantool.io/ui-kit';

import { styles } from './IconRebalancer.styles';

const Container = withTooltip('div');

export type IconRebalancerProps = {
  type: 'instance' | 'true' | 'false';
};

export const IconRebalancer = memo(({ type }: IconRebalancerProps) => {
  return (
    <Container
      tooltipContent={
        type === 'instance' ? 'Rebalancer instance' : type === 'false' ? 'Rebalancer: false' : 'Rebalancer: true'
      }
      className={cx(styles.root, styles[`type_${type}`])}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width={18}
        height={18}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path stroke="none" d="M0 0h24v24H0z" fill="none" />
        <path d="M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0" />
        <path d="M10 12h2a2 2 0 1 0 0 -4h-2v8m4 0l-3 -4" />
      </svg>
    </Container>
  );
});
