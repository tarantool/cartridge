// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';

const styles = {
  outer: ({ outer }) => css`
    padding: 8px 0 0;
    ${outer ? 'margin: 0 -16px;' : ''}
    list-style: none;
  `,
  item: css`
    padding: 12px 16px;
    margin-bottom: 8px;
    border-radius: 2px;
    background-color: #ffffff;
    box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.11);
  `,
  softCorners: css `
    border-radius: 4px;
    margin-bottom: 16px;
  `
};

type TiledListItemProps = {
  className?: string,
  corners?: 'hard' | 'soft',
  item: any,
  render: (any) => React.Node
};

const TiledListItem = ({ className, corners = 'hard', item, render }: TiledListItemProps) => (
  <li
    className={cx(
      styles.item,
      {
        [styles.softCorners]: corners === 'soft'
      },
      className
    )}
  >
    {render(item)}
  </li>
);

type TiledListProps = {
  className?: string,
  corners?: 'hard' | 'soft',
  itemClassName?: string,
  itemKey: string,
  items?: any[],
  itemRender: any => React.Node,
  outer?: boolean,
};

const TiledList = ({
  className,
  corners,
  itemClassName,
  itemKey,
  items,
  itemRender,
  outer = true
}:
TiledListProps) => (
  <ul className={cx(styles.outer({ outer }), className)}>
    {items && items.map(item => (
      <TiledListItem
        className={itemClassName}
        corners={corners}
        item={item}
        key={item[itemKey]}
        render={itemRender}
      />
    ))}
  </ul>
);

export default TiledList;
