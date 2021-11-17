import React from 'react';
import { sortableContainer, sortableElement } from 'react-sortable-hoc';
import { css, cx } from '@emotion/css';
import arrayMove from 'array-move';
import { IconBurger, LeaderFlagSmall, Text, UriLabel } from '@tarantool.io/ui-kit';

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
  `,
};

const SortableItem = sortableElement(({ item, isLeader, selfURI }) => (
  <div className={cx(styles.sortableItem, 'meta-test__FailoverServerList')}>
    <Text className={styles.alias} tag="div">
      <IconBurger className={styles.iconMargin} />
      {item.alias || item.uuid}
    </Text>
    {isLeader ? <LeaderFlagSmall className={cx(styles.leaderFlag, 'meta-test__LeaderFlag')} /> : null}
    <UriLabel className={styles.serverUriWrap} uri={item.uri} weAreHere={selfURI && item.uri === selfURI} />
  </div>
));

const SortableContainer = sortableContainer(({ children, className = '' }) => {
  return <div className={className}>{children}</div>;
});

const ServerSortableList = ({ failoverMode, itemClassName, onChange, value, key, replicaset, serverMap, selfURI }) => {
  const items = value;
  return (
    <SortableContainer
      helperClass={styles.helper}
      onSortEnd={({ oldIndex, newIndex }) => {
        onChange(arrayMove(items, oldIndex, newIndex));
      }}
      className={cx(styles.container, 'co')}
    >
      {items.map((item, index) => (
        <SortableItem
          className={itemClassName}
          key={item[key]}
          num={index}
          index={index}
          isLeader={
            failoverMode === 'stateful'
              ? replicaset.active_master && replicaset.active_master.uuid === serverMap[item].uuid
              : index === 0
          }
          item={serverMap[item]}
          selfURI={selfURI}
        />
      ))}
    </SortableContainer>
  );
};

export default ServerSortableList;
