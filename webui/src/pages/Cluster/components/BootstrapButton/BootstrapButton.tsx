import React, { useMemo } from 'react';
import { connect } from 'react-redux';
import { useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';
import { bootstrapVshard, setVisibleBootstrapVshardPanel } from 'src/store/actions/clusterPage.actions';

export interface BootstrapButtonProps {
  bootstrapVshard: () => void;
  requesting: boolean;
  setVisibleBootstrapVshardPanel: () => void;
}

const BootstrapButton = ({ bootstrapVshard, requesting, setVisibleBootstrapVshardPanel }: BootstrapButtonProps) => {
  const clusterStore = useStore(cluster.serverList.$cluster);
  const serverListStore = useStore(cluster.serverList.$serverList);
  const canBootstrapVshard = useMemo(
    () => cluster.serverList.selectors.canBootstrapVshard(serverListStore, clusterStore),
    [serverListStore, clusterStore]
  );

  // TODO: call getClusterSelf on ModalEditReplicaSet submit action
  return (
    <Button
      className="meta-test__BootstrapButton"
      disabled={requesting}
      intent="primary"
      text="Bootstrap vshard"
      onClick={canBootstrapVshard ? bootstrapVshard : setVisibleBootstrapVshardPanel}
      size="l"
    />
  );
};

const mapStateToProps = (state) => ({
  requesting: state.ui.requestingBootstrapVshard,
});

const mapDispatchToProps = {
  bootstrapVshard,
  setVisibleBootstrapVshardPanel,
};

export default connect(mapStateToProps, mapDispatchToProps)(BootstrapButton);
