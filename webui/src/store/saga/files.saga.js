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


function* applyFilesSaga() {
  try {
    const { files } = yield select();
    const updatedFiles = [];
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
          if (!filesMap[initialPath || path]) filesMap[initialPath || path] = [];
          filesMap[initialPath || path][0] = initialContent;
        }

        if (!deleted) {
          if (!filesMap[path]) filesMap[path] = [];
          filesMap[path][1] = content;
        }
      }
    }

    for (const path in filesMap) {
      if (filesMap.hasOwnProperty(path)) {
        if (typeof filesMap[path][1] !== 'string') {
          updatedFiles.push({ filename: path, content: null });
        } else if (filesMap[path][0] !== filesMap[path][1]) {
          updatedFiles.push({ filename: path, content: filesMap[path][1] });
        }
      }
    }

    if (updatedFiles.length) {
      const r = yield call(applyFiles, updatedFiles);
    }
    yield put({ type: PUT_CONFIG_FILES_CONTENT_DONE });
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
