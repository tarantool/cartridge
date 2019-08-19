// @flow
// TODO: move to uikit
import React from 'react';
import { css, cx } from 'emotion';
import * as R from 'ramda';

const COLORS = {
  success: '#52C41A',
  warning: '#FAAD14',
  danger: '#F5222D'
};

const style = css`
  position: relative;
  height: 4px;
  width: 100%;
  border-radius: 3px;
  background-color: #e1e1e1;

  &::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    height: 4px;
    min-width: 4px;
    border-radius: 3px;
  }
`;

const defineStatus = R.cond([
  [R.lt(66), R.always('danger')],
  [R.lt(33), R.always('warning')],
  [R.T, R.always('success')]
]);

type ProgressBarProps = {
  className?: string,
  percents: number,
  intention?: 'danger' | 'warning' | 'success'
};

const ProgressBar = ({
  className,
  percents,
  intention = defineStatus(percents)
}:
ProgressBarProps) => {
  const bar = css`
    &::before {
      width: ${percents}%;
      background-color: ${COLORS[intention]}
    }
  `;

  return <div className={cx(style, bar, className)} />;
};

export default ProgressBar;
