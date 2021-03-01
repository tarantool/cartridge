// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion'
import { setVisibleBootstrapVshardPanel } from '../store/actions/clusterPage.actions';
import { isBootstrapped, isRouterEnabled, isStorageEnabled } from '../store/selectors/clusterPage';
import { IconCancel, IconOk, PageCard, Text } from '@tarantool.io/ui-kit';
import type { State } from 'src/store/rootReducer';
import { selectVshardRolesNames } from 'src/store/selectors/clusterPage';

const styles = {
  iconMargin: css`
    margin-right: 8px;
  `,
  row: css`
    display: flex;
    align-items: center;
    margin-bottom: 16px;
  `
};

type Props = {
  bootstrapPanelVisible: bool,
  isBootstrapped: bool,
  requestingBootstrapVshard: bool,
  routerPresent: bool,
  storagePresent: bool,
  setVisibleBootstrapVshardPanel: (v: bool) => void,
  storageRolesNames: string[],
  routerRolesNames: string[]
};

const BootstrapPanel = (
  {
    bootstrapPanelVisible,
    isBootstrapped,
    requestingBootstrapVshard,
    routerPresent,
    storagePresent,
    setVisibleBootstrapVshardPanel,
    storageRolesNames,
    routerRolesNames
  }: Props
) => {
  if (!bootstrapPanelVisible || requestingBootstrapVshard || isBootstrapped)
    return null;

  return (
    <PageCard
      className='meta-test__BootstrapPanel'
      title="Bootstrap vshard"
      onClose={() => setVisibleBootstrapVshardPanel(false)}
      showCorner
    >
      <Text className={styles.row} variant='h4'>
        After you complete editing the topology, you need to bootstrap vshard to render storages operable.
      </Text>
      <Text className={styles.row}>
        {routerPresent
          ? <IconOk className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-router_enabled')} />
          : <IconCancel className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-router_disabled')} />}
        {routerRolesNames.length === 1
          ? `One role ${routerRolesNames[0]} enabled`
          : `One role from ${routerRolesNames.join(' or ')} enabled`}
      </Text>
      <Text className={styles.row}>
        {storagePresent
          ? <IconOk className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-storage_enabled')} />
          : <IconCancel className={cx(styles.iconMargin, 'meta-test__BootstrapPanel__vshard-storage_disabled')} />}
        {storageRolesNames.length === 1
          ? `One role ${storageRolesNames[0]} enabled`
          : `One role from ${storageRolesNames.join(' or ')} enabled`}
      </Text>
      <Text className={styles.row}>Afterwards, any change in topology will trigger data rebalancing</Text>
    </PageCard>
  );
};

const mapStateToProps = (state: State) => {
  const {
    ui: {
      requestingBootstrapVshard,
      bootstrapPanelVisible
    }
  } = state;
  const rolesNames = selectVshardRolesNames(state);

  return {
    bootstrapPanelVisible,
    isBootstrapped: isBootstrapped(state),
    requestingBootstrapVshard,
    routerPresent: isRouterEnabled(state),
    storagePresent: isStorageEnabled(state),
    storageRolesNames: rolesNames.storage,
    routerRolesNames: rolesNames.router
  }
};

const mapDispatchToProps = { setVisibleBootstrapVshardPanel };

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapPanel);
