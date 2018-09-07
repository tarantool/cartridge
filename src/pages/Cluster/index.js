import { connect } from 'react-redux';

import { evalString, saveConsoleState } from 'src/store/actions/app.actions';
import { createMessage } from 'src/store/actions/app.actions';
import { pageDidMount, selectServer, closeServerPopup, selectReplicaset, closeReplicasetPopup, probeServer, joinServer,
  createReplicaset, expellServer, editReplicaset, applyTestConfig, resetPageState }
  from 'src/store/actions/clusterPage.actions';
import Cluster from './Cluster';

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf,
      evalResult,
      savedConsoleState,
    },
    clusterPage: {
      pageMount,
      pageDataRequestStatus,
      selectedServerUri,
      selectedReplicasetUuid,
      serverList,
      replicasetList,
      serverStat,
      canTestConfigBeApplied,
    },
  } = state;

  return {
    clusterSelf,
    evalResult,
    savedConsoleState,
    pageMount,
    pageDataRequestStatus,
    selectedServerUri,
    selectedReplicasetUuid,
    serverList,
    replicasetList,
    serverStat,
    canTestConfigBeApplied,
  };
};

const mapDispatchToProps = {
  evalString,
  saveConsoleState,
  pageDidMount,
  selectServer,
  closeServerPopup,
  selectReplicaset,
  closeReplicasetPopup,
  probeServer,
  joinServer,
  createReplicaset,
  expellServer,
  editReplicaset,
  applyTestConfig,
  createMessage,
  resetPageState,
};

export default connect(mapStateToProps, mapDispatchToProps)(Cluster);
