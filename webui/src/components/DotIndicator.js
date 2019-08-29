// @flow
// move to uikit
import React from 'react';
import { css, cx } from 'emotion';

const styles = {
  indicator: css`
    display: inline-block;
    flex-shrink: 0;
    margin: 8px;
    background-color: rgba(110, 97, 160, 0.04);
    border-radius: 50%;
  `,
  state: {
    bad: css`background-color: #f5222d;`,
    good: css`background-color: #52c41a;`,
    middle: css`background-color: #faad14;`
  },
  size: {
    s: css`
      width: 6px;
      height: 6px;
    `
    // m: css`
    //   width: 13px;
    //   height: 13px;
    // `,
    // l: css`
    //   width: 16px;
    //   height: 16px;
    // `
  }
};

type DotIndicatorProps = {
  className?: string,
  // size?: 's',
  state: 'inactive' | 'good' | 'bad' | 'middle'
};

const DotIndicator = ({
  className,
  // size = 's',
  state = 'inactive'
}:
DotIndicatorProps) => {
  return (
    <span
      className={cx(
        styles.indicator,
        styles.state[state],
        styles.size.s,
        className
      )}
    />
  );
};

export default DotIndicator;
