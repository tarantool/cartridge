import { delay } from 'redux-saga';
import {
  call,
  cancel,
  fork,
  put,
  select,
  take,
  takeLatest,
  takeEvery
} from 'redux-saga/effects';
import { pageRequestIndicator } from 'src/misc/pageRequestIndicator';
import {
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  CLUSTER_PAGE_STATE_RESET,
  CLUSTER_SELF_UPDATE
} from 'src/store/actionTypes';
import { baseSaga, getRequestSaga, getSignalRequestSaga } from 'src/store/commonRequest';
import { getClusterSelf } from 'src/store/request/app.requests';
import {
  getPageData,
  refreshLists,
  getServerStat,
  bootstrapVshard,
  probeServer,
  joinServer,
  createReplicaset,
  expelServer,
  editReplicaset,
  uploadConfig,
  changeFailover
} from 'src/store/request/clusterPage.requests';
import { REFRESH_LIST_INTERVAL } from 'src/constants';

const STAT_REQUEST_PERIOD = 10;

const pageDataRequestSaga = getSignalRequestSaga(
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  getPageData,
);

function* refreshListsTaskSaga() {
  let requestNum = 0;

  while (true) {
    yield delay(REFRESH_LIST_INTERVAL);
    requestNum++;
    yield refreshListsSaga(requestNum);
  }
};

function* refreshListsSaga(requestNum = 0) {
  yield put({ type: CLUSTER_PAGE_REFRESH_LISTS_REQUEST });

  let response;
  try {
    const shouldRequestStat = requestNum % STAT_REQUEST_PERIOD === 0;
    if (shouldRequestStat) {
      response = yield call(refreshLists, { shouldRequestStat: true });
    } else {
      const listsResponse = yield call(refreshLists);

      let serverStatResponse;
      const serverStat = yield select(state => state.clusterPage.serverStat);
      const unknownServerExists = listsResponse.serverList
        .some(server => server.replicaset && !serverStat.find(stat => stat.uuid === server.uuid));
      if (unknownServerExists) {
        serverStatResponse = yield call(getServerStat);
      }

      response = {
        ...listsResponse,
        ...serverStatResponse
      };
    }
  } catch (error) {
    yield put({ type: CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR, error, requestPayload: {} });
  }
  if (response) {
    if (response.serverStat) {
      response = {
        ...response,
        serverStat: response.serverStat.filter(stat => stat.uuid)
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

function* bootstrapVshardRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST, function* load(action) {
    const {
      payload: requestPayload = {},
      __payload: {
        noIndicator,
        noErrorMessage,
        successMessage
      } = {}
    } = action;
    const indicator = noIndicator ? null : pageRequestIndicator.run();

    let response;
    try {
      response = yield call(bootstrapVshard, requestPayload);
      indicator && indicator.success();

      yield put({
        type: CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
        payload: response,
        requestPayload,
        __successMessage: successMessage
      });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: !noErrorMessage
      });
      indicator && indicator.error();
      return;
    }
  });
};

const probeServerRequestSaga = function* () {
  yield takeLatest(CLUSTER_PAGE_PROBE_SERVER_REQUEST, function* load(action) {
    const {
      payload: requestPayload = {},
      __payload: { successMessage } = {}
    } = action;
    const indicator = pageRequestIndicator.run();

    try {
      const response = yield call(probeServer, requestPayload);
      indicator.success();

      yield put({
        type: CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
        payload: response,
        __successMessage: successMessage
      });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
        payload: error,
        error: true
      });
      indicator.error();
      return;
    }
  });
};

function* joinServerRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_JOIN_SERVER_REQUEST, function* load(action) {
    const {
      payload: requestPayload = {},
      __payload: {
        noIndicator,
        noErrorMessage,
        successMessage
      } = {}
    } = action;
    const indicator = noIndicator ? null : pageRequestIndicator.run();

    let response;
    try {
      response = yield call(joinServer, requestPayload);
      indicator && indicator.success();

      yield put({
        type: CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
        payload: response,
        requestPayload,
        __successMessage: successMessage
      });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: !noErrorMessage
      });
      indicator && indicator.error();
      return;
    }
  });
};

function* createReplicasetRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_CREATE_REPLICASET_REQUEST, function* load(action) {
    const { payload: requestPayload = {} } = action;
    const indicator = pageRequestIndicator.run();

    let response;
    try {
      const createReplicasetResponse = yield call(createReplicaset, requestPayload);
      indicator.next();
      const clusterSelfResponse = yield call(getClusterSelf);
      indicator.success();

      response = {
        ...createReplicasetResponse,
        ...clusterSelfResponse
      };

      yield put({ type: CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS, payload: response, requestPayload });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: true
      });
      indicator.error();
      return;
    }
  });
};

function* expelServerRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_EXPEL_SERVER_REQUEST, function* load(action) {
    const {
      payload: requestPayload = {},
      __payload: {
        noIndicator,
        noErrorMessage,
        successMessage
      } = {}
    } = action;
    const indicator = noIndicator ? null : pageRequestIndicator.run();

    let response;
    try {
      response = yield call(expelServer, requestPayload);
      indicator && indicator.success();

      yield put({
        type: CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
        payload: response,
        requestPayload,
        __successMessage: successMessage
      });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: !noErrorMessage
      });
      indicator && indicator.error();
      return;
    }
  });
};

function* editReplicasetRequestSaga() {
  yield takeLatest(CLUSTER_PAGE_REPLICASET_EDIT_REQUEST, function* load(action) {
    const {
      payload: requestPayload = {},
      __payload: {
        noIndicator,
        noErrorMessage,
        successMessage
      } = {}
    } = action;
    const indicator = noIndicator ? null : pageRequestIndicator.run();

    let response;
    try {
      response = yield call(editReplicaset, requestPayload);
      indicator && indicator.success();

      yield put({
        type: CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
        payload: response,
        requestPayload,
        __successMessage: successMessage
      });

      yield refreshListsSaga();
    } catch (error) {
      yield put({
        type: CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
        error,
        requestPayload,
        __errorMessage: !noErrorMessage
      });
      indicator && indicator.error();
      return;
    }
  });
};

const uploadConfigRequestSaga = getRequestSaga(
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  uploadConfig,
);

const changeFailoverRequestSaga = getRequestSaga(
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  changeFailover,
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
  })
}

export const saga = baseSaga(
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
);
