// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';

const styles = {
  wrap: css`
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    margin-left: -16px;
    margin-right: -16px;
  `,
  input: css`
    margin: 0 16px 16px;
  `,
  columns: [
    css`flex-basis: 100%;`,
    css`flex-basis: calc(50% - 32px);`,
    css`flex-basis: calc(33.3% - 32px);`
  ]
};

type InputGroupProps = {
  children?: React.Node,
  className?: string,
  columns?: 1 | 2 | 3,
  itemClassName?: string
};

const InputGroup = ({
  children,
  className,
  columns = 1,
  itemClassName
}:
InputGroupProps) => (
  <div className={cx(styles.wrap, className)}>
    {children instanceof Array
      ? children.map(child => (
        <div className={cx(styles.input, styles.columns[columns - 1], itemClassName)}>{child}</div>
      ))
      : <div className={cx(styles.input, styles.columns[columns - 1], itemClassName)}>{children}</div>}
  </div>
);

export default InputGroup;
