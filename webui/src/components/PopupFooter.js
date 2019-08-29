import * as React from 'react';
import { css, cx } from 'emotion';
import ControlsPanel from 'src/components/ControlsPanel';

const styles = {
  wrap: css`
    display: flex;
    padding: 8px 16px;
  `,
  controls: css`
    padding-left: 16px;
    margin-left: auto;
  `
};

const PopupFooter = ({ children, className, controls }) => (
  <div className={cx(styles.wrap, className)}>
    {children}
    {controls && (
      <ControlsPanel className={cx(styles.controls)} thin>
        {controls}
      </ControlsPanel>
    )}
  </div>
);

export default PopupFooter;
