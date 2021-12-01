/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
// @ts-ignore
import { sortableContainer, sortableElement } from 'react-sortable-hoc';
import { cx } from '@emotion/css';
import arrayMove from 'array-move';
// @ts-ignore
import { IconBurger, LeaderFlagSmall, Text, UriLabel } from '@tarantool.io/ui-kit';

import type { ServerListReplicaset, ServerListReplicasetServer } from 'src/models';

import { styles } from './ServerSortableList.styles';

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

export interface ServerSortableListProps {
  value: string[];
  onChange: (value: string[]) => void;
  itemClassName?: string;
  replicaset: ServerListReplicaset;
  serverMap?: Record<string, ServerListReplicasetServer>;
  key: string;
  selfURI?: string;
  failoverMode?: string;
  largeMargins?: boolean;
}

const ServerSortableList = ({
  failoverMode,
  itemClassName,
  onChange,
  value,
  replicaset,
  serverMap,
  selfURI,
}: ServerSortableListProps) => {
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
          key={index}
          num={index}
          index={index}
          isLeader={
            failoverMode === 'stateful'
              ? replicaset.active_master && replicaset.active_master.uuid === serverMap?.[item]?.uuid
              : index === 0
          }
          item={serverMap?.[item]}
          selfURI={selfURI}
        />
      ))}
    </SortableContainer>
  );
};

export default ServerSortableList;
