import { call, put, select, takeEvery } from 'redux-saga/effects';
import { getErrorMessage } from 'src/api/';
import {
  FETCH_CONFIG_FILES,
  FETCH_CONFIG_FILES_DONE,
  FETCH_CONFIG_FILES_FAIL,
  PUT_CONFIG_FILES_CONTENT,
  PUT_CONFIG_FILES_CONTENT_DONE,
  PUT_CONFIG_FILES_CONTENT_FAIL
} from 'src/store/actionTypes';
import { applyFiles, getFiles } from 'src/store/request/files.requests';
import { baseSaga } from 'src/store/commonRequest';
import * as R from 'ramda';


function* applyFilesSaga() {
  try {
    const { files } = yield select();
    const updatedFiles = [];
    const initialMap = {};
    const filesMap = {};

    for (let i = 0; i < files.length; i++) {
      const {
        content,
        deleted,
        initialContent,
        initialPath,
        path,
        saved,
        type
      } = files[i];

      if (type === 'file') {
        if (initialContent !== '' || saved) { // Filter new files
          initialMap[initialPath || path] = initialContent
        }

        if (!deleted) {
          filesMap[path] = content;
        }
      }
    }

    const initialPaths = Object.keys(initialMap);
    const filesPaths = Object.keys(filesMap);

    const toDelete = R.difference(initialPaths, filesPaths);

    updatedFiles.push(...toDelete.map(filename => ({ filename, content: null })))

    for (const path in filesMap) {
      if (!initialPaths[path] || initialPaths[path] !== filesMap[path]) {
        updatedFiles.push({
          filename: path,
          content: filesMap[path]
        });
      }
    }

    if (updatedFiles.length) {
      const r = yield call(applyFiles, updatedFiles);
    }

    yield put({ type: PUT_CONFIG_FILES_CONTENT_DONE });
    window.tarantool_enterprise_core.notify({
      title: 'Success',
      message: 'Files successfuly applied',
      type: 'success',
      timeout: 5000
    });
  } catch (error) {
    yield put({
      type: PUT_CONFIG_FILES_CONTENT_FAIL,
      payload: error,
      error: true
    });
  }
};

function* fetchFilesSaga() {
  try {
    const response = yield call(getFiles);

    yield put({
      type: FETCH_CONFIG_FILES_DONE,
      payload: response
    });
  } catch (error) {
    yield put({
      type: FETCH_CONFIG_FILES_FAIL,
      error
    });
  }
}

function* filesSaga() {
  yield takeEvery(FETCH_CONFIG_FILES, fetchFilesSaga);
  yield takeEvery(PUT_CONFIG_FILES_CONTENT, applyFilesSaga);
}

export const saga = baseSaga(
  filesSaga
);
