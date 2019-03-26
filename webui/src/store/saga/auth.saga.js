import { call, put, takeLatest } from 'redux-saga/effects';
import {
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_ERROR,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_ERROR,
} from 'src/store/actionTypes';
import { baseSaga, getRequestSaga } from 'src/store/commonRequest';
import { logIn, logOut, turnAuth } from 'src/store/request/auth.requests';

const logInSaga = getRequestSaga(
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  logIn,
);

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

export const saga = baseSaga(
  logInSaga,
  logOutSaga,
  turnAuthSaga,
);
