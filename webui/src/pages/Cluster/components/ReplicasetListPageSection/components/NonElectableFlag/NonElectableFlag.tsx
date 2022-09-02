import React, { memo } from 'react';
import { css, cx } from '@emotion/css';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Tooltip } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    color: #333;
    opacity: 0.5;
  `,
};

export interface NonElectableFlagProps {
  className?: string;
}

export const NonElectableFlag = memo(({ className }: NonElectableFlagProps) => {
  return (
    <Tooltip content="Non-electable">
      <div className={cx(styles.root, className)}>
        <svg
          width="15"
          height="15"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
          <path d="M18 18h-13l-1.865 -9.327a0.25 .25 0 0 1 .4 -.244l4.465 3.571l1.6 -2.4m1.596 -2.394l.804 -1.206l4 6l4.464 -3.571a0.25 .25 0 0 1 .401 .244l-1.363 6.818"></path>
          <line x1="3" y1="3" x2="21" y2="21"></line>
        </svg>
      </div>
    </Tooltip>
  );
});
