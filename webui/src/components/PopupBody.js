// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';

const styles = {
  wrap: css`
    width: 100%;
    height: 100%;
  `
};

const PopupFooter = ({ children, className }) => (
  <div className={cx(styles.wrap, className)}>
    {children}
  </div>
);

export default PopupFooter;
