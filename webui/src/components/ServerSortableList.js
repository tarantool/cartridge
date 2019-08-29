import React from 'react'
import { sortableContainer, sortableElement } from 'react-sortable-hoc';
import styled, { css } from 'react-emotion';
import arrayMove from 'array-move'
import LeaderFlagSmall from 'src/components/LeaderFlagSmall';
import { IconLink } from 'src/components/Icon';
import Text from 'src/components/Text';


const styles = {
  popupBody: css`
    min-height: 100px;
    height: 80vh;
    max-height: 480px;
  `,
  form: css`
    /* margin-left: -16px;
    margin-right: -16px; */
  `,
  wrap: css`
    display: flex;
    flex-wrap: wrap;
  `,
  input: css`
    margin-bottom: 4px;
  `,
  aliasInput: css`
    width: 50%;
  `,
  uriIcon: css`
    margin-right: 4px;
  `,
  weightInput: css`
    width: 97px;
  `,
  errorMessage: css`
    display: block;
    height: 20px;
    color: #F5222D;
  `,
  radioWrap: css`
    display: flex;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  radio: css`
    max-width: 50%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  serverUriWrap: css`
    flex-basis: calc(50% - 24px);
    text-align: right;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  leaderFlag: css`
    flex-shrink: 0;
    align-self: center;
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
    &:last-child{
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
}

const SortableItem = sortableElement(({ item, num }) =>
  <div className={styles.sortableItem}>
    <div className={styles.radio}>{item.alias || item.uuid}</div>
    {num === 0 ?<LeaderFlagSmall  className={styles.leaderFlag} /> : null}
    <div className={styles.serverUriWrap}>
      <IconLink className={styles.uriIcon}/>
      <Text variant='h5' tag='span'>{item.uri}</Text>
    </div>
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
      className={styles.container}
    >
      {items.map((item, index) => (
        <SortableItem key={item[key]} num={index} index={index} item={serverMap[item]}/>
      ))}
    </SortableContainer>
  )
}
