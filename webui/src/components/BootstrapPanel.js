import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion'
import { setVisibleBootstrapVshardPanel } from '../store/actions/clusterPage.actions';
import { isBootstrapped, isRolePresentSelectorCreator } from '../store/selectors/clusterPage';
import PageCard from 'src/components/PageCard';
import { IconCancel, IconOk } from 'src/components/Icon';
import Text from 'src/components/Text';
import { VSHARD_STORAGE_ROLE_NAME, VSHARD_ROUTER_ROLE_NAME } from 'src/constants';
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

const isStoragePresent = isRolePresentSelectorCreator(VSHARD_STORAGE_ROLE_NAME);
const isRouterPresent = isRolePresentSelectorCreator(VSHARD_ROUTER_ROLE_NAME);

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
        <Text className={styles.row} variant='h4'>When you finish edition topology. To render storages operable.</Text>
        <Text className={styles.row}>
          {routerPresent ? <IconOk className={styles.iconMargin} /> : <IconCancel className={styles.iconMargin} />}
          One role vshard-router enabled
        </Text>
        <Text className={styles.row}>
          {storagePresent ? <IconOk className={styles.iconMargin} /> : <IconCancel className={styles.iconMargin} />}
          One role vshard-storage enabled
        </Text>
        <Text className={styles.row}>Afterwards, any change in topology will trigger data rebalancing</Text>
      </PageCard>
    );
  }
}

const mapStateToProps = (state: State) => {
  const {
    app: {
      clusterSelf
    },
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

const mapDispatchToProps = {
  setVisibleBootstrapVshardPanel
};

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapPanel);
