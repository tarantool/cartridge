// @flow
import React from 'react';
import { connect } from 'react-redux';
import { ControlsPanel } from '@tarantool.io/ui-kit';

import AuthToggleButton from 'src/components/AuthToggleButton';
import BootstrapButton from 'src/components/BootstrapButton';
import ClusterIssuesButton from 'src/components/ClusterIssuesButton';
import FailoverButton from 'src/components/FailoverButton';
import ProbeServerModal from 'src/components/ProbeServerModal';
import type { State } from 'src/store/rootReducer';
import { isBootstrapped, isVshardAvailable } from 'src/store/selectors/clusterPage';

type ClusterButtonsPanelProps = {
  showBootstrap: boolean,
  setProbeServerModalVisible: () => void,
  showFailover: boolean,
  showToggleAuth: boolean,
};

const ClusterButtonsPanel = ({ showBootstrap, showFailover, showToggleAuth }: ClusterButtonsPanelProps) => {
  return (
    <ControlsPanel
      className="meta-test__ButtonsPanel"
      controls={[
        <ClusterIssuesButton key={0} />,
        <ProbeServerModal key={1} />,
        showToggleAuth && <AuthToggleButton key={2} />,
        showFailover && <FailoverButton key={3} />,
        showBootstrap && <BootstrapButton key={4} />,
      ].filter(Boolean)}
      thin
    />
  );
};

const mapStateToProps = (state: State) => {
  const {
    clusterSelf,
    authParams: { implements_add_user, implements_check_password, implements_list_users },
  } = state.app;

  return {
    showFailover: !!(clusterSelf && clusterSelf.configured),
    showBootstrap: !!(clusterSelf && clusterSelf.configured) && isVshardAvailable(state) && !isBootstrapped(state),
    showToggleAuth: !implements_add_user && !implements_list_users && implements_check_password,
  };
};

export default connect(mapStateToProps)(ClusterButtonsPanel);
