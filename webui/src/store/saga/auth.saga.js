import {
  takeLatest,
  call,
  put,
  select
} from 'redux-saga/effects';
import { menuFilter } from 'src/menu';
import { baseSaga, getRequestSaga } from 'src/store/commonRequest';
import { logIn, logOut, turnAuth } from 'src/store/request/auth.requests';

import {
  APP_DID_MOUNT,
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_ERROR,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_ERROR
} from 'src/store/actionTypes';

function* logInSaga() {
  yield takeLatest(AUTH_LOG_IN_REQUEST, function* ({ payload }) {
    const { username, password } = payload;

    try {
      const response = yield call(logIn, { username, password });
      yield put({
        type: AUTH_LOG_IN_REQUEST_SUCCESS,
        payload: response
      });

      if (response.authorized) {
        window.tarantool_enterprise_core.dispatch('cluster:login:done', response);
        yield put({ type: APP_DID_MOUNT });
      }
    } catch (error) {
      yield put({
        type: AUTH_LOG_IN_REQUEST_ERROR,
        error
      });
      return;
    }
  });
}

function* logOutSaga() {
  yield takeLatest(AUTH_LOG_OUT_REQUEST, function* () {
    const { auth: { authorizationEnabled } } = yield select();

    try {
      const response = yield call(logOut);

      yield put({ type: AUTH_LOG_OUT_REQUEST_SUCCESS, payload: response });
      window.tarantool_enterprise_core.dispatch('cluster:logout:done');

      if (authorizationEnabled) {
        menuFilter.hideAll();
        window.tarantool_enterprise_core.dispatch('dispatchToken', { type: '' });
      }
    } catch (error) {
      yield put({ type: AUTH_LOG_OUT_REQUEST_ERROR, error });
      return;
    }
  });
};

const turnAuthSaga = getRequestSaga(
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_ERROR,
  turnAuth
);

export const saga = baseSaga(
  logInSaga,
  logOutSaga,
  turnAuthSaga
);
