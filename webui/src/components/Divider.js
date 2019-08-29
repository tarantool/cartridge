// @flow
// move to uikit
import React from 'react';
import { css, cx } from 'emotion';

const styles = {
  divider: css`
    height: 1px;
    margin-bottom: 12px;
    background-color: #e8e8e8;
  `
};

type DividerProps = {
  className?: string
};

const Divider = ({ className }: DividerProps) => (
  <div className={cx(styles.divider, className)} />
);

export default Divider;
