// @flow
// TODO: move to uikit
import * as React from 'react'
import { css, cx } from 'react-emotion'

const styles = {
  alert: css`
    padding: 16px;
    border: 1px solid;
    border-radius: 4px;
  `,
  success: css`
    border-color: #b5ec8e;
    background-color: #f6ffee;
  `,
  error: css`
    border-color: #fea39e;
    background-color: #fff1f0;
  `
};

type AlertProps = {
  className?: string,
  children: React.Node,
  type: 'error' | 'success',
};

export default ({
  className,
  children,
  type
}: AlertProps) => {
  return (
    <div className={cx(styles.alert, styles[type], className)}>
      {children}
    </div>
  );
}
