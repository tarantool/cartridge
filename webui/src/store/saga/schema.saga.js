import { call, put, select, takeEvery } from 'redux-saga/effects';
import { getErrorMessage } from 'src/api/';
import {
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST,
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_ERROR,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST_ERROR,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_ERROR
} from 'src/store/actionTypes';
import { applySchema, getSchema, checkSchema } from 'src/store/request/schema.requests';
import { baseSaga } from 'src/store/commonRequest';

function* getSchemaSaga() {
  try {
    const response = yield call(getSchema);
    yield put({ type: CLUSTER_PAGE_SCHEMA_GET_REQUEST_SUCCESS, payload: response });
  } catch (error) {
    yield put({
      type: CLUSTER_PAGE_SCHEMA_GET_REQUEST_ERROR,
      error
    });
  }
};

function* applySchemaSaga() {
  try {
    const { schema: { value } } = yield select();
    yield call(applySchema, value);
    yield put({ type: CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_SUCCESS });
  } catch (error) {
    yield put({
      type: CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_ERROR,
      payload: error,
      error: true
    });
  }
};

function* validateSchemaSaga() {
  try {
    const { schema: { value } } = yield select();
    yield put({ type: CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_SUCCESS });
    const { cluster: { check_schema: { error } } } = yield call(checkSchema, value);

    window.tarantool_enterprise_core.notify({
      title: 'Schema validation',
      message: error || 'Schema is valid',
      type: error ? 'error' : 'success',
      timeout: error ? 30000 : 10000
    });
  } catch (error) {
    const errorText = getErrorMessage(error);
    yield put({
      type: CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_ERROR,
      payload: errorText,
      error: true
    });
    window.tarantool_enterprise_core.notify({
      title: 'Unexpected error',
      message: errorText,
      type: 'error',
      timeout: 30000
    });
  }
};

function* schemaSaga() {
  yield takeEvery(CLUSTER_PAGE_SCHEMA_APPLY_REQUEST, applySchemaSaga);
  yield takeEvery(CLUSTER_PAGE_SCHEMA_GET_REQUEST, getSchemaSaga);
  yield takeEvery(CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST, validateSchemaSaga);
}

export const saga = baseSaga(
  schemaSaga
);
