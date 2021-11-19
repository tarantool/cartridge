/* eslint-disable @typescript-eslint/ban-ts-comment */
// TODO: split and move to uikit
import React, { memo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Text, UriLabel } from '@tarantool.io/ui-kit';

import { styles } from './SelectedServersList.styles';

export interface SelectedServersListProps {
  className?: string;
  selfURI?: string;
  serverList?: Array<{ alias?: string | null | undefined; uri: string }>;
}

const SelectedServersList = ({ className, selfURI, serverList }: SelectedServersListProps) => (
  <ul className={cx(styles.serversList, className)}>
    <Text variant="h3">{`Selected server${serverList && serverList.length > 1 ? 's' : ''}`}</Text>
    {serverList &&
      serverList.map((server) => (
        <li key={`${server.alias}~${server.uri}`} className={styles.serversListItem}>
          <Text className={styles.serverListItemAlias} variant="p" tag="span">
            {server.alias}
          </Text>
          <UriLabel
            uri={server.uri}
            weAreHere={selfURI && selfURI === server.uri}
            className={selfURI && selfURI === server.uri && 'meta-test__youAreHereIcon'}
          />
        </li>
      ))}
  </ul>
);

export default memo(SelectedServersList);
