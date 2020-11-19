import { all } from 'redux-saga/effects';

import { saga as appSaga } from 'src/store/saga/app.saga';
import { saga as authSaga } from 'src/store/saga/auth.saga';
import { saga as clusterPageSaga } from 'src/store/saga/clusterPage.saga';
import { saga as clusterInstancePageSaga } from 'src/store/saga/clusterInstancePage.saga';
import { saga as editorSaga } from 'src/store/saga/editor.saga';
import { saga as schemaSaga } from 'src/store/saga/schema.saga';
import { saga as filesSaga } from 'src/store/saga/files.saga';

export default function* rootSaga() {
  yield all([
    appSaga,
    authSaga,
    clusterPageSaga,
    clusterInstancePageSaga,
    editorSaga,
    schemaSaga,
    filesSaga
  ].map(saga => saga()));
}
