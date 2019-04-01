import { all } from 'redux-saga/effects';

import { saga as appSaga } from 'src/store/saga/app.saga';
import { saga as authSaga } from 'src/store/saga/auth.saga';
import { saga as clusterPageSaga } from 'src/store/saga/clusterPage.saga';
import { saga as clusterInstancePageSaga } from 'src/store/saga/clusterInstancePage.saga';

export default function* rootSaga() {
  yield all([
    appSaga,
    authSaga,
    clusterPageSaga,
    clusterInstancePageSaga
  ].map(saga => saga()));
}
