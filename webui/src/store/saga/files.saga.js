import { call, put, select, takeEvery } from 'redux-saga/effects';
import { getErrorMessage } from 'src/api/';
import {
  PUT_CONFIG_FILE_CONTENT,
  PUT_CONFIG_FILE_CONTENT_DONE,
  PUT_CONFIG_FILE_CONTENT_FAIL,
} from 'src/store/actionTypes';
import { applyFiles } from 'src/store/request/files.requests';
import { baseSaga } from 'src/store/commonRequest';


function* applyFilesSaga() {
  try {
    const { files } = yield select();

    const updatedFiles = [];
    const deletedFiles = [];
    files.forEach(file => {
      if (file.deleted) {
        deletedFiles.push(file);
        return;
      }

      const fileWasRenamed = file.initialPath && file.initialPath !== file.path;
      // const fileWasEdited = file.initialContent && file.initialContent !== file.content;

      if (file.saved === false || fileWasRenamed) {
        updatedFiles.push(file);
      }
    });

    yield call(applyFiles, updatedFiles, deletedFiles);
    yield put({ type: PUT_CONFIG_FILE_CONTENT_DONE });
  } catch (error) {
    yield put({
      type: PUT_CONFIG_FILE_CONTENT_FAIL,
      payload: error,
      error: true
    });
  }
};

function* filesSaga() {
  yield takeEvery(PUT_CONFIG_FILE_CONTENT, applyFilesSaga);
}

export const saga = baseSaga(
  filesSaga
);
