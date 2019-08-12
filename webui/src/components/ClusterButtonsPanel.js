// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { isBootstrapped } from 'src/store/selectors/clusterPage';
import FailoverButton from 'src/components/FailoverButton';
import BootstrapButton from 'src/components/BootstrapButton';
import ProbeServerModal from 'src/components/ProbeServerModal';
import { PageSection } from '@tarantool.io/ui-kit';
import type { State } from 'src/store/rootReducer';

type ClusterButtonsPanelProps = {
  showBootstrap: boolean,
  setProbeServerModalVisible: () => void,
  showFailover: boolean
};

const ClusterButtonsPanel = (
  {
    showBootstrap,
    showFailover
  }: ClusterButtonsPanelProps) => {
  return (
    <PageSection
      className='meta-test__FailoverSwitcherBtn'
      topRightControls={[
        <ProbeServerModal />,
        showFailover && <FailoverButton />,
        showBootstrap && <BootstrapButton />
      ]}
    />
  );
};

const mapStateToProps = (state: State) => {
  const { clusterSelf } = state.app;

  return {
    showFailover: !!(clusterSelf && clusterSelf.configured),
    showBootstrap: !isBootstrapped(state)
  }
};

export default connect(mapStateToProps)(ClusterButtonsPanel);
