import { delay } from 'redux-saga';
import { call, cancel, fork, put, select, take } from 'redux-saga/effects';
import core from '@tarantool.io/frontend-core';

import { REFRESH_LIST_INTERVAL } from 'src/constants';
import {
  CLUSTER_INSTANCE_DATA_REQUEST,
  CLUSTER_INSTANCE_DATA_REQUEST_ERROR,
  CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_DID_MOUNT,
  CLUSTER_INSTANCE_REFRESH_REQUEST,
  CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR,
  CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_STATE_RESET,
} from 'src/store/actionTypes';
import { baseSaga, getSignalRequestSaga } from 'src/store/commonRequest';
import { getInstanceData, refreshInstanceData } from 'src/store/request/clusterInstancePage.requests';

const pageDataRequestSaga = getSignalRequestSaga(
  CLUSTER_INSTANCE_DID_MOUNT,
  CLUSTER_INSTANCE_DATA_REQUEST,
  CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_DATA_REQUEST_ERROR,
  getInstanceData
);

function* refreshInstanceStatsSaga() {
  while (true) {
    const { cartridge_refresh_interval } = core.variables;
    yield delay(parseInt(cartridge_refresh_interval || REFRESH_LIST_INTERVAL));
    yield put({ type: CLUSTER_INSTANCE_REFRESH_REQUEST });

    let response;
    try {
      const instanceUUID = yield select((state) => state.clusterInstancePage.instanceUUID);
      response = yield call(refreshInstanceData, { instanceUUID });
    } catch (error) {
      yield put({ type: CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR, error, requestPayload: {} });
    }
    if (response) {
      if (response.serverStat) {
        response = {
          ...response,
          serverStat: response.serverStat.filter((stat) => stat.uuid),
        };
      }
      yield put({ type: CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS, payload: response, requestPayload: {} });
    }
  }
}

function* refreshInstanceRequestSaga() {
  while (true) {
    yield take(CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS);
    const refreshInstanceStats = yield fork(refreshInstanceStatsSaga);
    yield take(CLUSTER_INSTANCE_STATE_RESET);
    yield cancel(refreshInstanceStats);
  }
}

export const saga = baseSaga(pageDataRequestSaga, refreshInstanceRequestSaga);
