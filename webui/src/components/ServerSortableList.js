import React from 'react'
import { sortableContainer, sortableElement } from 'react-sortable-hoc';
import { css, cx } from 'react-emotion';
import arrayMove from 'array-move'
import LeaderFlagSmall from 'src/components/LeaderFlagSmall';
import { IconBurger } from 'src/components/Icon';
import Text from 'src/components/Text';
import UriLabel from 'src/components/UriLabel';

const styles = {
  uriIcon: css`
    margin-right: 4px;
  `,
  alias: css`
    flex-basis: 404px;
    max-width: 404px;
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  serverUriWrap: css`
    flex-basis: 445px;
    max-width: 445px;
    justify-content: flex-end;
    margin-left: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  leaderFlag: css`
    flex-shrink: 0;
    align-self: center;
    margin-left: 8px;
    margin-right: 8px;
  `,
  iconMargin: css`
    margin-right: 8px;
  `,
  sortableItem: css`
    position: relative;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;
    display: flex; 
    flex-direction: row;
    cursor: move;

    &:last-child {
      border-bottom: none;
    }
  `,
  helper: css`
    z-index: 120;
  `,
  container: css`
    display: flex; 
    flex-direction: column; 
    width: 100%;
  `
}

const SortableItem = sortableElement(({ item, num }) =>
  <div className={styles.sortableItem}>
    <Text className={styles.alias} tag='div'>
      <IconBurger className={styles.iconMargin} />
      {item.alias || item.uuid}
    </Text>
    {num === 0 ?<LeaderFlagSmall  className={styles.leaderFlag} /> : null}
    <UriLabel className={styles.serverUriWrap} uri={item.uri} />
  </div>
);

const SortableContainer = sortableContainer(({ children, className = '' }) => {
  return <div className={className}>{children}</div>;
});

export const ServerSortableList = ({ onChange, value, key, serverMap }) => {
  const items = value
  return (
    <SortableContainer
      helperClass={styles.helper}
      onSortEnd={({ oldIndex, newIndex }) => {
        onChange(arrayMove(items, oldIndex, newIndex))
      }}
      className={cx(styles.container, 'co')}
    >
      {items.map((item, index) => (
        <SortableItem key={item[key]} num={index} index={index} item={serverMap[item]}/>
      ))}
    </SortableContainer>
  )
}
