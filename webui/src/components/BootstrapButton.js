// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import {
  isBootstrapped as checkIsBootstrapped,
  isRouterPresent,
  isStoragePresent
} from 'src/store/selectors/clusterPage';
import { bootstrapVshard, setVisibleBootstrapVshardPanel } from 'src/store/actions/clusterPage.actions';
import { Button } from '@tarantool.io/ui-kit';
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
      className='meta-test__BootstrapButton'
      disabled={requesting}
      intent='primary'
      text='Bootstrap vshard'
      onClick={can_bootstrap_vshard ? bootstrapVshard : setVisibleBootstrapVshardPanel}
      size='l'
    />
  );
};

const mapStateToProps = (state: State) => ({
  can_bootstrap_vshard: (isRouterPresent(state) && isStoragePresent(state)) || false,
  isBootstrapped: checkIsBootstrapped(state),
  requesting: state.ui.requestingBootstrapVshard
});

const mapDispatchToProps = {
  bootstrapVshard,
  setVisibleBootstrapVshardPanel
};

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapButton);
