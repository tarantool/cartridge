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
    const errorText = getErrorMessage(error);
    yield put({
      type: CLUSTER_PAGE_SCHEMA_GET_REQUEST_ERROR,
      payload: errorText,
      error: true
    });
  }
};

function* applySchemaSaga() {
  try {
    const { schema: { value } } = yield select();
    yield call(applySchema, value);
    yield put({ type: CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_SUCCESS });

    window.tarantool_enterprise_core.notify({
      title: 'Success',
      message: 'Schema successfully applied',
      type: 'success',
      timeout: 10000
    });
  } catch (error) {
    const errorText = getErrorMessage(error);
    yield put({
      type: CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_ERROR,
      payload: errorText,
      error: true
    });
  }
};

function* validateSchemaSaga() {
  try {
    const { schema: { value } } = yield select();
    const { cluster: { check_schema: { error } } } = yield call(checkSchema, value);
    yield put({ type: CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_SUCCESS, payload: error });

    if (!error) {
      window.tarantool_enterprise_core.notify({
        title: 'Schema validation',
        message: 'Schema is valid',
        type: 'success',
        timeout: 10000
      });
    }
  } catch (error) {
    const errorText = getErrorMessage(error);
    yield put({
      type: CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_ERROR,
      payload: errorText,
      error: true
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
