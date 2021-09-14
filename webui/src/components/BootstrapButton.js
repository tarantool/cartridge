// @flow
import React from 'react';
import { connect } from 'react-redux';
import { Button } from '@tarantool.io/ui-kit';

import { bootstrapVshard, setVisibleBootstrapVshardPanel } from 'src/store/actions/clusterPage.actions';
import type { State } from 'src/store/rootReducer';
import { isRouterEnabled, isStorageEnabled } from 'src/store/selectors/clusterPage';

type Props = {
  bootstrapVshard: () => void,
  can_bootstrap_vshard: boolean,
  requesting: boolean,
  setVisibleBootstrapVshardPanel: () => void,
};

const BootstrapButton = ({
  bootstrapVshard,
  can_bootstrap_vshard,
  requesting,
  setVisibleBootstrapVshardPanel,
}: Props) => {
  // TODO: call getClusterSelf on ModalEditReplicaSet submit action
  return (
    <Button
      className="meta-test__BootstrapButton"
      disabled={requesting}
      intent="primary"
      text="Bootstrap vshard"
      onClick={can_bootstrap_vshard ? bootstrapVshard : setVisibleBootstrapVshardPanel}
      size="l"
    />
  );
};

const mapStateToProps = (state: State) => ({
  can_bootstrap_vshard: (isRouterEnabled(state) && isStorageEnabled(state)) || false,
  requesting: state.ui.requestingBootstrapVshard,
});

const mapDispatchToProps = {
  bootstrapVshard,
  setVisibleBootstrapVshardPanel,
};

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapButton);
