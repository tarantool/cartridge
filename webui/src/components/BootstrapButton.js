// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { isBootstrapped as checkIsBootstrapped } from 'src/store/selectors/clusterPage';
import { bootstrapVshard, setVisibleBootstrapVshardPanel } from 'src/store/actions/clusterPage.actions';
import Button from 'src/components/Button';
import type { State } from 'src/store/rootReducer';

const BootstrapButton = ({
  bootstrapVshard,
  can_bootstrap_vshard,
  isBootstrapped,
  requesting,
  setVisibleBootstrapVshardPanel
}) => {
  if (isBootstrapped)
    return null;
  // TODO: call getClusterSelf on ModalEditReplicaSet submit action
  return (
    <Button
      disabled={requesting}
      intent='primary'
      text='Bootstrap vshard'
      onClick={can_bootstrap_vshard ? bootstrapVshard : setVisibleBootstrapVshardPanel}
    />
  );
};

const mapStateToProps = (state: State) => {
  const { app, ui } = state;

  return {
    can_bootstrap_vshard: (app.clusterSelf && app.clusterSelf.can_bootstrap_vshard) || false,
    isBootstrapped: checkIsBootstrapped(state),
    requesting: ui.requestingBootstrapVshard
  }
};

const mapDispatchToProps = {
  bootstrapVshard,
  setVisibleBootstrapVshardPanel
};

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapButton);
