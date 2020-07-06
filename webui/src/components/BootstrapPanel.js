import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion'
import { setVisibleBootstrapVshardPanel } from '../store/actions/clusterPage.actions';
import { isBootstrapped, isRouterPresent, isStoragePresent } from '../store/selectors/clusterPage';
import { IconCancel, IconOk, PageCard, Text } from '@tarantool.io/ui-kit';
import type { State } from 'src/store/rootReducer';

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

class BootstrapPanel extends React.Component {
  render() {
    const {
      bootstrapPanelVisible,
      isBootstrapped,
      requestingBootstrapVshard,
      routerPresent,
      storagePresent,
      setVisibleBootstrapVshardPanel
    } = this.props;

    if (!bootstrapPanelVisible || requestingBootstrapVshard || isBootstrapped)
      return null;

    return (
      <PageCard title="Bootstrap vshard" onClose={() => setVisibleBootstrapVshardPanel(false)} showCorner>
        <Text className={styles.row} variant='h4'>
          After you complete editing the topology, you need to bootstrap vshard to render storages operable.
        </Text>
        <Text className={styles.row}>
          {routerPresent
            ? <IconOk className={cx(styles.iconMargin, 'meta-test__BootStrapPanel__vshard-router_enabled')} />
            : <IconCancel className={cx(styles.iconMargin, 'meta-test__BootStrapPanel__vshard-router_disabled')} />}
          One role vshard-router enabled
        </Text>
        <Text className={styles.row}>
          {storagePresent
            ? <IconOk className={cx(styles.iconMargin, 'meta-test__BootStrapPanel__vshard-storage_enabled')} />
            : <IconCancel className={cx(styles.iconMargin, 'meta-test__BootStrapPanel__vshard-storage_disabled')} />}
          One role vshard-storage enabled
        </Text>
        <Text className={styles.row}>Afterwards, any change in topology will trigger data rebalancing</Text>
      </PageCard>
    );
  }
}

const mapStateToProps = (state: State) => {
  const {
    ui: {
      requestingBootstrapVshard,
      bootstrapPanelVisible
    }
  } = state;

  return {
    bootstrapPanelVisible,
    isBootstrapped: isBootstrapped(state),
    requestingBootstrapVshard,
    routerPresent: isRouterPresent(state),
    storagePresent: isStoragePresent(state)
  }
};

const mapDispatchToProps = { setVisibleBootstrapVshardPanel };

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapPanel);
