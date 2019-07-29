// @flow
import { connect } from 'react-redux';
import { createMessage } from 'src/store/actions/app.actions';
import {
  pageDidMount,
  selectServer,
  closeServerPopup,
  selectReplicaset,
  closeReplicasetPopup,
  bootstrapVshard,
  probeServer,
  joinServer,
  createReplicaset,
  expelServer,
  editReplicaset,
  uploadConfig,
  applyTestConfig,
  changeFailover,
  resetPageState,
  setVisibleBootstrapVshardModal,
  setFilter
} from 'src/store/actions/clusterPage.actions';
import {
  getReplicasetCounts,
  getServerCounts,
  filterReplicasetList,
  selectReplicasetListWithStat
} from 'src/store/selectors/clusterPage';
import Cluster from './Cluster';
import type { State } from 'src/store/rootReducer';

const mapStateToProps = (state: State) => {
  const {
    app: {
      clusterSelf,
      failover,
      authParams: {
        implements_add_user,
        implements_check_password,
        implements_list_users
      }
    },
    clusterPage: {
      pageMount,
      pageDataRequestStatus,
      replicasetFilter,
      selectedServerUri,
      selectedReplicasetUuid,
      serverList
    },
    ui: {
      showBootstrapModal
    }
  } = state;

  const replicasetList = selectReplicasetListWithStat(state);

  return {
    clusterSelf,
    failover,
    filter: replicasetFilter,
    filteredReplicasetList: replicasetFilter
      ? filterReplicasetList(state)
      : replicasetList,
    pageMount,
    pageDataRequestStatus,
    replicasetCounts: getReplicasetCounts(state),
    replicasetList,
    selectedServerUri,
    selectedReplicasetUuid,
    serverList,
    serverCounts: getServerCounts(state),
    showBootstrapModal,
    showToggleAuth: !(implements_add_user || implements_list_users) && implements_check_password
  };
};

const mapDispatchToProps = {
  pageDidMount,
  selectServer,
  closeServerPopup,
  selectReplicaset,
  closeReplicasetPopup,
  bootstrapVshard,
  probeServer,
  joinServer,
  createReplicaset,
  expelServer,
  editReplicaset,
  uploadConfig,
  applyTestConfig,
  createMessage,
  changeFailover,
  resetPageState,
  setVisibleBootstrapVshardModal,
  setFilter
};

export default connect(mapStateToProps, mapDispatchToProps)(Cluster);
