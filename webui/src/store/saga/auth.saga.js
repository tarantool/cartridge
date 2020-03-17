import {
  takeLatest,
  takeEvery,
  call,
  put,
  select
} from 'redux-saga/effects';
import { isGraphqlAccessDeniedError } from 'src/api/graphql';
import { isRestAccessDeniedError } from 'src/api/rest';
import { menuFilter } from 'src/menu';
import { baseSaga, getRequestSaga } from 'src/store/commonRequest';
import { logIn, logOut, turnAuth } from 'src/store/request/auth.requests';
import { pageRequestIndicator } from 'src/misc/pageRequestIndicator';

import {
  APP_DID_MOUNT,
  AUTH_ACCESS_DENIED,
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
    const indicator = pageRequestIndicator.run();

    try {
      const response = yield call(logIn, { username, password });
      indicator.success();
      yield put({
        type: AUTH_LOG_IN_REQUEST_SUCCESS,
        payload: response
      });
      window.tarantool_enterprise_core.dispatch('cluster:login:done', response);

      if (response.authorized) {
        yield put({ type: APP_DID_MOUNT });
      }
    } catch (error) {
      yield put({
        type: AUTH_LOG_IN_REQUEST_ERROR,
        error
      });
      indicator.error();
      return;
    }
  });
}

function* logOutSaga() {
  yield takeLatest(AUTH_LOG_OUT_REQUEST, function* () {
    const indicator = pageRequestIndicator.run();
    const { auth: { authorizationEnabled } } = yield select();

    try {
      const response = yield call(logOut);
      indicator && indicator.success();

      yield put({ type: AUTH_LOG_OUT_REQUEST_SUCCESS, payload: response });
      window.tarantool_enterprise_core.dispatch('cluster:logout:done');

      if (authorizationEnabled) {
        menuFilter.hideAll();
        window.tarantool_enterprise_core.dispatch('dispatchToken', { type: '' });
      }
    } catch (error) {
      yield put({ type: AUTH_LOG_OUT_REQUEST_ERROR, error });
      indicator && indicator.error();
      return;
    }
  });
};

const turnAuthSaga = getRequestSaga(
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_ERROR,
  turnAuth,
);

export const saga = baseSaga(
  logInSaga,
  logOutSaga,
  turnAuthSaga
);
