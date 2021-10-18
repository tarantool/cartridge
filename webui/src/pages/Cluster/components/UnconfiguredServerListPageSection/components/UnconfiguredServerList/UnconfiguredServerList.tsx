/* eslint-disable @typescript-eslint/ban-ts-comment */
// TODO: move to uikit
import React, { MouseEvent, memo, useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Button, HealthStatus, Text, TiledList, TiledListItem, UriLabel } from '@tarantool.io/ui-kit';

import { GetClusterClusterSelf, ServerListServer, app, cluster } from 'src/models';

import { styles } from './UnconfiguredServerList.styles';

const { isLike } = app.utils;
const { selectors } = cluster.serverList;
const { serverConfigureModalOpenedEvent } = cluster.serverConfigure;

export interface UnconfiguredServerListProps {
  className?: string;
  clusterSelf?: GetClusterClusterSelf;
  servers: ServerListServer[];
}

const UnconfiguredServerList = ({ className, servers, clusterSelf }: UnconfiguredServerListProps) => {
  const sortedServersList = useMemo(
    () => selectors.sortUnConfiguredServerList(servers, clusterSelf),
    [servers, clusterSelf]
  );

  const handleConfigureButtonClick = useCallback((_: MouseEvent<HTMLButtonElement>, pass?: unknown) => {
    if (isLike<ServerListServer>(pass)) {
      serverConfigureModalOpenedEvent({ uri: pass.uri });
    }
  }, []);

  return (
    <TiledList className={cx(className, 'meta-test__UnconfiguredServerList')} outer={false}>
      {sortedServersList.map((item) => (
        <TiledListItem key={item.uuid} className={styles.row} itemKey={item.uri}>
          <div className={styles.heading}>
            <Text variant="h4" tag="span">
              {item.alias}
            </Text>
            <UriLabel
              uri={item.uri}
              weAreHere={clusterSelf?.uri && item.uri === clusterSelf.uri}
              className={clusterSelf?.uri && item.uri === clusterSelf.uri && 'meta-test__youAreHereIcon'}
            />
          </div>
          <HealthStatus className={styles.status} status={item.status} message={item.message} />
          <Button
            className={cx(styles.configureBtn, 'meta-test__configureBtn', {
              [styles.hiddenButton]: !(clusterSelf?.uuid || clusterSelf?.uri === item.uri),
            })}
            intent="secondary"
            onClick={handleConfigureButtonClick}
            text="Configure"
            pass={item}
          />
        </TiledListItem>
      ))}
    </TiledList>
  );
};

export default memo(UnconfiguredServerList);
