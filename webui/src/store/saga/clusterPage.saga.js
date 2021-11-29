import { delay } from 'redux-saga';
import { call, cancel, fork, put, select, take, takeEvery, takeLatest } from 'redux-saga/effects';
import { core } from '@tarantool.io/frontend-core';

import { REFRESH_LIST_INTERVAL, STAT_REQUEST_PERIOD } from 'src/constants';
import { graphqlErrorNotification } from 'src/misc/graphqlErrorNotification';
import {
  CLUSTER_DISABLE_INSTANCE_REQUEST,
  CLUSTER_DISABLE_INSTANCE_REQUEST_ERROR,
  CLUSTER_DISABLE_INSTANCE_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST,
  CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_REQUEST,
  CLUSTER_PAGE_FAILOVER_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_STATE_RESET,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_ZONE_UPDATE,
  CLUSTER_SELF_UPDATE,
} from 'src/store/actionTypes';
import { baseSaga, getRequestSaga, getSignalRequestSaga } from 'src/store/commonRequest';
import { statsResponseError, statsResponseSuccess } from 'src/store/effector/cluster';
import { getClusterSelf } from 'src/store/request/app.requests';
import {
  bootstrapVshard,
  changeFailover,
  createReplicaset,
  disableServer,
  editReplicaset,
  expelServer,
  getFailover,
  getPageData,
  getServerStat,
  joinServer,
  probeServer,
  promoteFailoverLeader,
  refreshLists,
  uploadConfig,
} from 'src/store/request/clusterPage.requests';

const pageDataRequestSaga = getSignalRequestSaga(
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  () =>
    getPageData().then((data) => {
      statsResponseSuccess(data);
      return data;
    })
);

function* refreshListsTaskSaga() {
  let requestNum = 0;

  while (true) {
    const { cartridge_refresh_interval } = core.variables;
    yield delay(parseInt(cartridge_refresh_interval || REFRESH_LIST_INTERVAL));
    requestNum++;
    yield refreshListsSaga(requestNum);
  }
}

function* refreshListsSaga(requestNum = 0) {
  yield put({ type: CLUSTER_PAGE_REFRESH_LISTS_REQUEST });

  let response;
  try {
    const { cartridge_stat_period } = core.variables;
    const shouldRequestStat = requestNum % parseInt(cartridge_stat_period || STAT_REQUEST_PERIOD) === 0;
    if (shouldRequestStat) {
      response = yield call(refreshLists, { shouldRequestStat: true });
      statsResponseSuccess(response);
    } else {
      const listsResponse = yield call(refreshLists);

      let serverStatResponse;
      const serverStat = yield select((state) => state.clusterPage.serverStat);
      const unknownServerExists = listsResponse.serverList.some(
        (server) => server.replicaset && !serverStat.find((stat) => stat.uuid === server.uuid)
      );
      if (unknownServerExists) {
        serverStatResponse = yield call(getServerStat);
      }

      response = {
        ...listsResponse,
        ...serverStatResponse,
      };
    }
  } catch (error) {
    statsResponseError(error.message);
    yield put({ type: CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR, error, requestPayload: {} });
  }
  if (response) {
    if (response.serverStat) {
      response = {
        ...response,
        serverStat: response.serverStat.filter((stat) => stat.uuid),
      };
    }

    if (response.failover) {
      response = {
        ...response,
        failoverMode: response.failover.failover_params.mode,
      };
    }

    yield put({ type: CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS, payload: response, requestPayload: {} });
  }
}

function* refreshListsRequestSaga() {
  while (true) {
    yield take(CLUSTER_PAGE_DATA_REQUEST_SUCCESS);
    const refreshListsTask = yield fork(refreshListsTaskSaga);
    yield take(CLUSTER_PAGE_STATE_RESET);
    yield cancel(refreshListsTask);
  }
}

const bootstrapVshardRequestSaga = getRequestSaga(
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  bootstrapVshard
);

const probeServerRequestSaga = function* () {
  yield takeLatest(CLUSTER_PAGE_PROBE_SERVER_REQUEST, function* load(action) {
    const { payload: requestPayload = {}, __payload: { successMessage } = {} } = action;

    try {
      const response = yield call(probeServer, requestPayload);

      yield put({
        type: CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
        payload: response,
        __successMessage: successMessage,
      });
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
        payload: error,
        error: true,
      });
      return;
    }
  });
};

const failoverPromoteRequestSaga = function* () {
  yield takeLatest(CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST, function* ({ payload }) {
    try {
      yield call(promoteFailoverLeader, payload);
      yield put({ type: CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_SUCCESS });

      core.notify({
        title: 'Failover',
        message: 'Leader promotion successful',
        type: 'success',
        timeout: 5000,
      });
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_ERROR,
        payload: error,
        error: true,
      });
      graphqlErrorNotification(error, 'Leader promotion error');
    }
  });
};

const disableInstanceSaga = function* () {
  yield takeLatest(CLUSTER_DISABLE_INSTANCE_REQUEST, function* ({ payload: { uuid, disable } }) {
    try {
      yield call(disableServer, uuid, disable);
      yield put({ type: CLUSTER_DISABLE_INSTANCE_REQUEST_SUCCESS });
    } catch (error) {
      yield put({
        type: CLUSTER_DISABLE_INSTANCE_REQUEST_ERROR,
        payload: error,
        error: true,
      });
      graphqlErrorNotification(error, 'Disabled state setting error');
    }
  });
};

const joinServerRequestSaga = getRequestSaga(
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  joinServer
);

function* createReplicasetRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_CREATE_REPLICASET_REQUEST, function* load(action) {
    const { payload: requestPayload = {} } = action;

    let response;
    try {
      const createReplicasetResponse = yield call(createReplicaset, requestPayload);
      const clusterSelfResponse = yield call(getClusterSelf);

      response = {
        ...createReplicasetResponse,
        ...clusterSelfResponse,
      };

      yield put({ type: CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS, payload: response, requestPayload });
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: true,
      });

      return;
    }
  });
}

function* changeFailoverRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST, function* ({ payload: requestPayload = {} }) {
    try {
      const response = yield call(changeFailover, requestPayload);

      yield put({ type: CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS, payload: response });

      core.notify({
        title: 'Failover mode',
        message: response.failover_params.mode,
        type: 'success',
        timeout: 5000,
      });
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
        error,
      });
      return;
    }
  });
}

const expelServerRequestSaga = getRequestSaga(
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  expelServer
);

const editReplicasetRequestSaga = getRequestSaga(
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  editReplicaset
);

const uploadConfigRequestSaga = getRequestSaga(
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  uploadConfig
);

const updateClusterSelfOnBootstrap = function* () {
  yield takeEvery(CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS, function* () {
    while (true) {
      try {
        const clusterSelfResponse = yield call(getClusterSelf);
        yield put({ type: CLUSTER_SELF_UPDATE, payload: clusterSelfResponse });
        return;
      } catch (e) {
        yield delay(2000);
      }
    }
  });
};

const updateListsOnTopologyEdit = function* () {
  const topologyEditTokens = [
    CLUSTER_DISABLE_INSTANCE_REQUEST_SUCCESS,
    CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
    CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
    CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
    CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_SUCCESS,
    CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
    CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
    CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
    CLUSTER_PAGE_ZONE_UPDATE,
  ];

  yield takeLatest(topologyEditTokens, function* () {
    yield refreshListsSaga();
  });
};

const getFailoverParamsRequestSaga = getRequestSaga(
  CLUSTER_PAGE_FAILOVER_REQUEST,
  CLUSTER_PAGE_FAILOVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_REQUEST_ERROR,
  getFailover
);

export const saga = baseSaga(
  failoverPromoteRequestSaga,
  disableInstanceSaga,
  pageDataRequestSaga,
  refreshListsRequestSaga,
  bootstrapVshardRequestSaga,
  probeServerRequestSaga,
  joinServerRequestSaga,
  createReplicasetRequestSaga,
  expelServerRequestSaga,
  editReplicasetRequestSaga,
  uploadConfigRequestSaga,
  changeFailoverRequestSaga,
  updateClusterSelfOnBootstrap,
  updateListsOnTopologyEdit,
  getFailoverParamsRequestSaga
);
