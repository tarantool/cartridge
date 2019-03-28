import { takeLatest, call, put } from 'redux-saga/effects';
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
  AUTH_LOG_OUT_REQUEST_ERROR,
  AUTH_RESTORE_REQUEST,
  AUTH_RESTORE_REQUEST_SUCCESS,
  AUTH_RESTORE_REQUEST_ERROR
} from 'src/store/actionTypes';
import { baseSaga, getRequestSaga } from 'src/store/commonRequest';
import { logIn, logOut, turnAuth, getAuthState } from 'src/store/request/auth.requests';
import { pageRequestIndicator } from 'src/misc/pageRequestIndicator';

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

      if (response.authorized) {
        yield put({ type: APP_DID_MOUNT });
      }
    }
    catch (error) {
      yield put({
        type: AUTH_LOG_IN_REQUEST_ERROR,
        error
      });
      indicator.error();
      return;
    }
  });
}

const logOutSaga = getRequestSaga(
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_ERROR,
  logOut,
);

const turnAuthSaga = getRequestSaga(
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_ERROR,
  turnAuth,
);

const restoreAuthSaga = getRequestSaga(
  AUTH_RESTORE_REQUEST,
  AUTH_RESTORE_REQUEST_SUCCESS,
  AUTH_RESTORE_REQUEST_ERROR,
  getAuthState,
);

export const saga = baseSaga(
  logInSaga,
  logOutSaga,
  turnAuthSaga,
  restoreAuthSaga,
);
