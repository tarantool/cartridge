import { delay } from 'redux-saga';
import { call, put, select, take, takeEvery, takeLatest } from 'redux-saga/effects';
import { core } from '@tarantool.io/frontend-core';

import { SERVER_NOT_REACHABLE_ERROR_TYPE, getErrorMessage as getApiErrorMessage, isDeadServerError } from 'src/api';
import { menuFilter } from 'src/menu';
import { graphqlErrorNotification } from 'src/misc/graphqlErrorNotification';
import {
  APP_CREATE_MESSAGE,
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_ERROR,
  APP_DATA_REQUEST_SUCCESS,
  APP_DID_MOUNT,
  APP_RELOAD_CLUSTER_SELF,
  APP_RELOAD_CLUSTER_SELF_ERROR,
  APP_RELOAD_CLUSTER_SELF_SUCCESS,
  APP_SET_MESSAGE_DONE,
} from 'src/store/actionTypes';
import { baseSaga } from 'src/store/commonRequest';
import { getClusterSelf } from 'src/store/request/app.requests';

function* reloadClusterSelfRequestSaga() {
  yield takeLatest(APP_RELOAD_CLUSTER_SELF, function* reload() {
    try {
      const response = yield call(getClusterSelf);

      yield put({ type: APP_RELOAD_CLUSTER_SELF_SUCCESS, payload: response });
    } catch (error) {
      yield put({ type: APP_RELOAD_CLUSTER_SELF_ERROR, error });
    }
  });
}

function* appDataRequestSaga() {
  yield takeLatest(APP_DID_MOUNT, function* load(action) {
    const { payload: requestPayload = {} } = action;

    yield put({ type: APP_DATA_REQUEST, payload: requestPayload });

    let response;
    try {
      const clusterSelfResponse = yield call(getClusterSelf);
      const { app_name, instance_name } = clusterSelfResponse.clusterSelf;

      if (app_name || instance_name) {
        core.dispatch('setAppName', [app_name, instance_name].filter((i) => i).join('.'));
      }

      const { implements_add_user, implements_list_users } = clusterSelfResponse.authParams;

      menuFilter.set(clusterSelfResponse.MenuBlacklist);
      core.dispatch('dispatchToken', { type: '' });

      if (implements_add_user || implements_list_users) {
        core.dispatch('dispatchToken', {
          type: 'ADD_CLUSTER_USERS_MENU_ITEM',
          payload: {
            location: core.history.location,
          },
        });
      }

      response = {
        ...clusterSelfResponse,
      };
    } catch (error) {
      yield put({ type: APP_DATA_REQUEST_ERROR, error, requestPayload, __errorMessage: false });
      return undefined;
    }

    yield put({ type: APP_DATA_REQUEST_SUCCESS, payload: response, requestPayload });
  });
}

function* getActiveDeadServerMessage() {
  const messages = yield select((state) => state.app.messages);
  return messages.find((message) => message.type === SERVER_NOT_REACHABLE_ERROR_TYPE && !message.done);
}

function* appMessageSaga() {
  while (true) {
    const action = yield take('*');

    if (action.error && isDeadServerError(action.error)) {
      const activeDeadServerMessage = yield call(getActiveDeadServerMessage);
      if (!activeDeadServerMessage) {
        const messageText = 'It seems like server is not reachable';
        const messageType = 'error';

        const messagePayload = {
          content: { type: messageType, text: messageText },
          type: SERVER_NOT_REACHABLE_ERROR_TYPE,
        };
        yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

        graphqlErrorNotification(action.error);
      }
    } else {
      if (action.requestPayload) {
        const activeDeadServerMessage = yield call(getActiveDeadServerMessage);
        if (activeDeadServerMessage) {
          yield put({ type: APP_SET_MESSAGE_DONE, payload: activeDeadServerMessage });
        }
      }

      if (action.error && action.__errorMessage) {
        const messageText = getApiErrorMessage(action.error);
        const messageType = 'error';

        const messagePayload = {
          content: { type: messageType, text: messageText },
        };
        yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

        graphqlErrorNotification(action.error);
      }
    }

    if (action.__successMessage) {
      const messageText = action.__successMessage;
      const messageType = 'success';

      const messagePayload = {
        content: { type: messageType, text: messageText },
      };
      yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

      core.notify({
        title: 'Successful!',
        message: messageText,
        type: messageType,
        timeout: 5000,
      });
    }
  }
}

function* doneMessage() {
  yield takeEvery(APP_CREATE_MESSAGE, function* (action) {
    if (action.payload.content.type === 'success') {
      yield delay(3000);
      yield put({ type: APP_SET_MESSAGE_DONE, payload: { content: action.payload.content } });
    }
  });
}

export const saga = baseSaga(appDataRequestSaga, appMessageSaga, doneMessage, reloadClusterSelfRequestSaga);
