/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { MouseEvent, useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { Button, Text, TiledList, TiledListItem, Tooltip, UriLabel } from '@tarantool.io/ui-kit';

import { ServerListServer, cluster } from 'src/models';

import { styles } from './UnconfiguredServerList.styles';

const { selectors, $cluster } = cluster.serverList;
const { serverConfigureModalOpenedEvent } = cluster.serverConfigure;

export interface UnconfiguredServerListProps {
  servers: ServerListServer[];
}

const UnconfiguredServerList = ({ servers }: UnconfiguredServerListProps) => {
  const clusterStore = useStore($cluster);

  const clusterSelf = useMemo(() => selectors.clusterSelf(clusterStore), [clusterStore]);

  const sortedServersList = useMemo(
    () => selectors.sortUnConfiguredServerList(servers, clusterSelf),
    [servers, clusterSelf]
  );

  const handleConfigureButtonClick = useCallback((_: MouseEvent<HTMLButtonElement>, pass?: ServerListServer) => {
    if (pass) {
      serverConfigureModalOpenedEvent({ uri: pass.uri });
    }
  }, []);

  return (
    <TiledList className="meta-test__UnconfiguredServerList" outer={false}>
      {sortedServersList.map((item) => (
        <TiledListItem key={item.uuid} className={styles.row} corners="soft">
          <div className={styles.sign}>
            {clusterSelf?.uri && item.uri === clusterSelf.uri && (
              <Tooltip content="WebUI operates here">
                <UriLabel weAreHere className="meta-test__youAreHereIcon" />
              </Tooltip>
            )}
          </div>
          <Text variant="h4" tag="span" className={styles.alias}>
            {item.alias}
          </Text>
          <div className={styles.div} />
          <div className={styles.label}>
            <UriLabel uri={item.uri} />
          </div>
          {(clusterSelf?.uuid || clusterSelf?.uri === item.uri) && (
            <>
              <div className={cx(styles.div, styles.grow)} />
              <Button
                className={cx(styles.actions, 'meta-test__configureBtn')}
                intent="secondary"
                onClick={handleConfigureButtonClick}
                text="Configure"
                pass={item}
              />
            </>
          )}
        </TiledListItem>
      ))}
    </TiledList>
  );
};

export default UnconfiguredServerList;
