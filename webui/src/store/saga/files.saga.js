import { difference } from 'ramda';
import { call, put, select, takeEvery } from 'redux-saga/effects';
import core from '@tarantool.io/frontend-core';

import { graphqlErrorNotification } from 'src/misc/graphqlErrorNotification';
import { getFileIdForMonaco, getModelValueByFile, setModelValueByFile } from 'src/misc/monacoModelStorage';
import {
  FETCH_CONFIG_FILES,
  FETCH_CONFIG_FILES_DONE,
  FETCH_CONFIG_FILES_FAIL,
  PUT_CONFIG_FILES_CONTENT,
  PUT_CONFIG_FILES_CONTENT_DONE,
  PUT_CONFIG_FILES_CONTENT_FAIL,
  VALIDATE_CODE_FILES,
  VALIDATE_CODE_FILES_DONE,
  VALIDATE_CODE_FILES_FAIL,
} from 'src/store/actionTypes';
import { baseSaga } from 'src/store/commonRequest';
import { applyFiles, getFiles, validateFiles } from 'src/store/request/files.requests';

function* applyFilesSaga() {
  try {
    const {
      codeEditor: { files },
    } = yield select();
    const updatedFiles = [];
    const initialMap = {};
    const filesMap = {};

    for (let i = 0; i < files.length; i++) {
      const { fileId, deleted, initialContent, initialPath, path, saved, type } = files[i];

      // We don't keep all content in Redux store anymore. Get it from Monaco models:
      const contentIfEdited = getModelValueByFile(getFileIdForMonaco(fileId));
      const content = (contentIfEdited !== null ? contentIfEdited : initialContent) || '';

      if (type === 'file') {
        if (initialContent !== '' || saved) {
          // Filter new files
          initialMap[initialPath || path] = initialContent;
        }

        if (!deleted) {
          filesMap[path] = content;
        }
      }
    }

    const initialPaths = Object.keys(initialMap);
    const filesPaths = Object.keys(filesMap);

    const toDelete = difference(initialPaths, filesPaths);

    updatedFiles.push(...toDelete.map((filename) => ({ filename, content: null })));

    for (const path in filesMap) {
      if (!initialPaths[path] || initialPaths[path] !== filesMap[path]) {
        updatedFiles.push({
          filename: path,
          content: filesMap[path],
        });
      }
    }

    if (updatedFiles.length) {
      yield call(applyFiles, updatedFiles);
      yield call(fetchFilesSaga);
    }

    yield put({ type: PUT_CONFIG_FILES_CONTENT_DONE });
    core.notify({
      title: 'Success',
      message: 'Files successfuly applied',
      type: 'success',
      timeout: 5000,
    });
  } catch (error) {
    yield put({
      type: PUT_CONFIG_FILES_CONTENT_FAIL,
      payload: error,
      error: true,
    });

    graphqlErrorNotification(error);
  }
}

function* fetchFilesSaga({ payload: { initial } = {} } = {}) {
  try {
    const response = yield call(getFiles);

    // We don't keep all content in Redux store anymore. Put it to Monaco models:
    const {
      codeEditor: { files: localFiles },
    } = yield select();
    localFiles.forEach((localFile) => {
      const responseFile = response.find((f) => f.path === localFile.path);
      if (responseFile) {
        const fileIdForMonaco = getFileIdForMonaco(localFile.fileId);
        const localContent = getModelValueByFile(fileIdForMonaco);

        // Don't set same content - so we'll keep "redo" history
        if (localContent !== responseFile.content) {
          setModelValueByFile(fileIdForMonaco, responseFile.content);
        }
      }
    });

    yield put({
      type: FETCH_CONFIG_FILES_DONE,
      payload: response,
    });
  } catch (error) {
    yield put({
      type: FETCH_CONFIG_FILES_FAIL,
      error,
    });

    if (!initial) {
      graphqlErrorNotification(error);
    }
  }
}

function* validateFilesSaga() {
  try {
    const {
      codeEditor: { files },
    } = yield select();
    const filesArr = [];

    for (let i = 0; i < files.length; i++) {
      const { fileId, deleted, initialContent, path, type } = files[i];

      // We don't keep all content in Redux store anymore. Get it from Monaco models:
      const contentIfEdited = getModelValueByFile(getFileIdForMonaco(fileId));
      const content = (contentIfEdited !== null ? contentIfEdited : initialContent) || '';

      if (type === 'file' && !deleted) {
        filesArr.push({ filename: path, content });
      }
    }

    const { error } = yield call(validateFiles, filesArr);
    if (error) {
      yield put({ type: VALIDATE_CODE_FILES_FAIL });
      core.notify({
        title: 'Code validation failed',
        message: error,
        type: 'error',
        timeout: 5000,
      });
    } else {
      yield put({ type: VALIDATE_CODE_FILES_DONE });
      core.notify({
        title: 'The code is valid',
        type: 'success',
        timeout: 5000,
      });
    }
  } catch (error) {
    yield put({ type: VALIDATE_CODE_FILES_FAIL });
    graphqlErrorNotification(error);
  }
}

function* filesSaga() {
  yield takeEvery(FETCH_CONFIG_FILES, fetchFilesSaga);
  yield takeEvery(PUT_CONFIG_FILES_CONTENT, applyFilesSaga);
  yield takeEvery(VALIDATE_CODE_FILES, validateFilesSaga);
}

export const saga = baseSaga(filesSaga);
