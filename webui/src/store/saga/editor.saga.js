import { put, select, takeLatest } from 'redux-saga/effects';
import { FETCH_CONFIG_FILES_DONE, SELECT_FILE } from 'src/store/actionTypes';
import { LS_CODE_EDITOR_OPENED_FILE } from 'src/constants';

let initiallyOpened = false;

const getDepth = str => (str.match(/\//g) || []).length;

const getFileToOpen = (files = []) => (
  files
    .sort((a, b) => {
      if (getDepth(a.path) === getDepth(b.path))
        return a.path < b.path ? -1 : 1;
      return getDepth(a.path) < getDepth(b.path) ? -1 : 1;
    })
    .find(({ type }) => type === 'file')
);

function* openFirstFileSaga() {
  const { codeEditor: { files, editor: { selectedFile } } } = yield select();

  if (selectedFile === null && files && files.length > 0) {
    let file;
    const storedPath = localStorage.getItem(LS_CODE_EDITOR_OPENED_FILE);

    if (storedPath !== null) {
      file = files.find(({ type, path }) => type === 'file' && path === storedPath);
      if (!file)
        file = getFileToOpen(files)
    } else {
      file = getFileToOpen(files)
    }

    yield put({ type: SELECT_FILE, payload: file.fileId });
    initiallyOpened = true;
  }
};

function* storeOpenedFileSaga() {
  const { codeEditor: { files, editor: { selectedFile } } } = yield select();
  if (initiallyOpened) {
    const { path } = files.find(({ fileId }) => selectedFile === fileId);

    localStorage.setItem(LS_CODE_EDITOR_OPENED_FILE, path);
  }
}

export function* saga() {
  yield takeLatest(FETCH_CONFIG_FILES_DONE, openFirstFileSaga);
  yield takeLatest(SELECT_FILE, storeOpenedFileSaga);
}
