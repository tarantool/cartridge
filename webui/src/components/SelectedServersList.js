// @flow
// TODO: split and move to uikit
import React from 'react';
import { css, cx } from 'react-emotion';
import { IconLink } from 'src/components/Icon';
import Text from 'src/components/Text';
import type { Server } from 'src/generated/graphql-typing';

const styles = {
  serversList: css`
    padding: 16px;
    background: #FFFFFF;
    border: 1px solid #E8E8E8;
    margin: 0 0 24px;
    box-sizing: border-box;
    box-shadow: 0px 1px 10px rgba(0, 0, 0, 0.06);
    border-radius: 4px;
    list-style: none;

    & > * {
      margin-bottom: 4px;
    }

    & > *:last-child {
      margin-bottom: 0;
    }
  `,
  serversListItem: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
  `,
  serverListItemAlias: css`
    margin-right: 16px;
  `,
  serverListItemUri: css`
    display: flex;
    align-items: center;
  `,
  iconMargin: css`
    margin-right: 8px;
  `
}

type SelectedServersListProps = {
  className?: string,
  serverList?: Server[],
}

const SelectedServersList = ({ className, serverList }: SelectedServersListProps) => (
  <ul className={cx(styles.serversList, className)}>
    <Text variant='h3'>Selected servers:</Text>
    {serverList.map(server => (
      <li className={styles.serversListItem}>
        <Text className={styles.serverListItemAlias} variant='h5' tag='span'>{server.alias}</Text>
        <Text variant='p' tag='span'><IconLink className={styles.iconMargin} />{server.uri}</Text>
      </li>
    ))}
  </ul>
);

export default SelectedServersList;
