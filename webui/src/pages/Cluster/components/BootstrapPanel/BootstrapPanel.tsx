/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { IconCancel, IconOk, PageCard, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './BootstrapPanel.styles';

const { selectors, $serverList, $cluster, $bootstrapPanel, $knownRolesNames, hideBootstrapPanelEvent } =
  cluster.serverList;

const BootstrapPanel = () => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);
  const knownRolesNames = useStore($knownRolesNames);
  const { visible } = useStore($bootstrapPanel);

  const [isRouterEnabled, isStorageEnabled, isVshardBootstrapped] = useMemo(
    () => [
      selectors.isRouterEnabled(serverListStore, clusterStore),
      selectors.isStorageEnabled(serverListStore, clusterStore),
      selectors.isVshardBootstrapped(clusterStore),
    ],
    [serverListStore, clusterStore]
  );

  if (!visible || isVshardBootstrapped) {
    return null;
  }

  return (
    <PageCard
      className="meta-test__BootstrapPanel"
      title="Bootstrap vshard"
      onClose={() => hideBootstrapPanelEvent()}
      showCorner
    >
      <Text className={styles.row} variant="h4">
        After you complete editing the topology, you need to bootstrap vshard to render storages operable.
      </Text>
      <Text className={styles.row}>
        {isRouterEnabled ? (
          <IconOk className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-router_enabled')} />
        ) : (
          <IconCancel className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-router_disabled')} />
        )}
        {knownRolesNames.router.length === 1
          ? `One role ${knownRolesNames.router[0]} enabled`
          : `One role from ${knownRolesNames.router.join(' or ')} enabled`}
      </Text>
      <Text className={styles.row}>
        {isStorageEnabled ? (
          <IconOk className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-storage_enabled')} />
        ) : (
          <IconCancel className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-storage_disabled')} />
        )}
        {knownRolesNames.storage.length === 1
          ? `One role ${knownRolesNames.storage[0]} enabled`
          : `One role from ${knownRolesNames.storage.join(' or ')} enabled`}
      </Text>
      <Text className={styles.row}>Afterwards, any change in topology will trigger data rebalancing</Text>
    </PageCard>
  );
};

export default BootstrapPanel;
