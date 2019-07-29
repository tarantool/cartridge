import { call, put, select, takeEvery } from 'redux-saga/effects';
import { getErrorMessage } from 'src/api/';

import {
  addUser,
  editUser,
  getUserList,
  removeUser
} from 'src/store/request/users.requests';

import { baseSaga } from 'src/store/commonRequest';

import {
  APP_CREATE_MESSAGE,
  USER_LIST_REQUEST,
  USER_LIST_REQUEST_SUCCESS,
  USER_LIST_REQUEST_ERROR,
  USER_ADD_REQUEST,
  USER_ADD_REQUEST_SUCCESS,
  USER_ADD_REQUEST_ERROR,
  USER_EDIT_REQUEST,
  USER_EDIT_REQUEST_SUCCESS,
  USER_EDIT_REQUEST_ERROR,
  USER_REMOVE_REQUEST,
  USER_REMOVE_REQUEST_SUCCESS,
  USER_REMOVE_REQUEST_ERROR
} from 'src/store/actionTypes';

function* getUserListSaga() {
  try {
    const { app: { authParams } } = yield select();
    const isFeatureEnabled = authParams.implements_list_users === true;

    if (isFeatureEnabled) {
      const response = yield call(getUserList);
      yield put({ type: USER_LIST_REQUEST_SUCCESS, payload: response });
    } else {
      yield put({ type: USER_LIST_REQUEST_SUCCESS, payload: { items: [] } });
    }
  } catch (error) {
    yield put({
      type: USER_LIST_REQUEST_ERROR,
      error
    });
  }
};

function* addUserSaga({ payload }) {
  try {
    yield call(addUser, payload);
    yield put({ type: USER_ADD_REQUEST_SUCCESS });
    yield put({ type: USER_LIST_REQUEST });
  } catch (error) {
    yield put({
      type: USER_ADD_REQUEST_ERROR,
      error
    });
  }
};

function* removeUserSaga({ payload: { username } }) {
  try {
    yield call(removeUser, username);
    yield put({ type: USER_REMOVE_REQUEST_SUCCESS });
    yield put({ type: USER_LIST_REQUEST });
  } catch (error) {
    const errorText = getErrorMessage(error);

    yield put({
      type: USER_REMOVE_REQUEST_ERROR,
      error
    });

    yield put({ type: USER_LIST_REQUEST });
    yield put({
      type: APP_CREATE_MESSAGE,
      payload: {
        content: { type: 'danger', text: errorText },
        type: USER_REMOVE_REQUEST_ERROR
      }
    });
  }
};

function* editUserSaga({ payload }) {
  try {
    yield call(editUser, payload);
    yield put({ type: USER_EDIT_REQUEST_SUCCESS });
    yield put({ type: USER_LIST_REQUEST });
  } catch (error) {
    yield put({
      type: USER_EDIT_REQUEST_ERROR,
      error
    });
  }
};

function* usersSaga() {
  yield takeEvery(USER_LIST_REQUEST, getUserListSaga);
  yield takeEvery(USER_ADD_REQUEST, addUserSaga);
  yield takeEvery(USER_EDIT_REQUEST, editUserSaga);
  yield takeEvery(USER_REMOVE_REQUEST, removeUserSaga);
}

export const saga = baseSaga(
  usersSaga
);
