// @flow
// TODO: move to uikit
import * as React from 'react';
import * as R from 'ramda';
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
  column: css`
    align-self: stretch;
    margin: 0 16px;
  `,
  columnInput: css`
    margin-bottom: 16px;
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
  itemClassName?: string,
  verticalSort?: boolean
};

const renderers = {
  horizontal: (children, columns, itemClassName) => children instanceof Array
    ? children.map(child => (
      <div className={cx(styles.input, styles.columns[columns - 1], itemClassName)}>{child}</div>
    ))
    : <div className={cx(styles.input, styles.columns[columns - 1], itemClassName)}>{children}</div>,
  vertical: (children, columns, itemClassName) => {
    const items = children instanceof Array ? children : [children];
    const columnSize = Math.ceil(items.length / columns);
    const groupedItems: React.Node[][] = R.times(() => [], columns);

    items.forEach((item: React.Node = null, i) => {
      const column = Math.floor(i / columnSize);
      groupedItems[column].push(item);
    });

    return groupedItems.map(group => (
      <div className={cx(styles.column, styles.columns[columns - 1])}>
        {group.map(child => (
          <div className={cx(styles.columnInput, itemClassName)}>{child}</div>
        ))}
      </div>
    ));
  }
}

const InputGroup = ({
  children,
  className,
  columns = 1,
  itemClassName,
  verticalSort
}:
InputGroupProps) => {
  const renderer = verticalSort ? renderers.vertical : renderers.horizontal;
  return (
    <div className={cx(styles.wrap, className)}>
      {renderer(children, columns, itemClassName)}
    </div>
  );
};

export default InputGroup;
