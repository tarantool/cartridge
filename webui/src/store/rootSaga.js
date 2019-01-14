import { all } from 'redux-saga/effects';

import { saga as appSaga } from 'src/store/saga/app.saga';
import { saga as clusterPageSaga } from 'src/store/saga/clusterPage.saga';

export default function* rootSaga() {
  yield all([
    appSaga,
    clusterPageSaga,
  ].map(saga => saga()));
}
