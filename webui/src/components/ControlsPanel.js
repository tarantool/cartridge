// @flow
// TODO: move to uikit
import * as React from 'react';
import type { ComponentType } from 'react';
import { css, cx } from 'emotion';

const styles = {
  outer: css`
    display: flex;
    align-items: center;
  `,
  button: css`
    display: block;
    margin-right: 24px;

    &:last-child {
      margin-right: 0px;
    }
  `,
  thin: css`
    margin-right: 16px;
  `
};

type ControlsPanelProps = {
  className?: string,
  children?: React.Node,
  thin?: boolean // use thin in modals
};

const ControlsPanel = ({
  className,
  children,
  thin
}:
ControlsPanelProps) => (
  <div className={cx(styles.outer, className)}>
    {children instanceof Array
      ? children.map(button => button
        ? <div className={cx(styles.button, { [styles.thin]: thin })}>{button}</div>
        : null)
      : <div className={cx(styles.button, { [styles.thin]: thin })}>{children}</div>}
  </div>
);

export default ControlsPanel;
