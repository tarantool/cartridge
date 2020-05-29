import { delay } from 'redux-saga';
import {
  call,
  put,
  select,
  take,
  takeEvery,
  takeLatest
} from 'redux-saga/effects';
import { getErrorMessage as getApiErrorMessage, isDeadServerError, SERVER_NOT_REACHABLE_ERROR_TYPE } from 'src/api';
import { pageRequestIndicator } from 'src/misc/pageRequestIndicator';
import { menuFilter } from 'src/menu';
import {
  APP_DID_MOUNT,
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  APP_CREATE_MESSAGE,
  APP_SET_MESSAGE_DONE
} from 'src/store/actionTypes';
import { baseSaga } from 'src/store/commonRequest';
import { getClusterSelf } from 'src/store/request/app.requests';

function* appDataRequestSaga() {
  yield takeLatest(APP_DID_MOUNT, function* load(action) {
    const { payload: requestPayload = {} } = action;
    const indicator = pageRequestIndicator.run();

    yield put({ type: APP_DATA_REQUEST, payload: requestPayload });

    let response;
    try {
      const clusterSelfResponse = yield call(getClusterSelf);
      const { app_name, instance_name } = clusterSelfResponse.clusterSelf;

      if (app_name || instance_name) {
        window.tarantool_enterprise_core.dispatch(
          'setAppName',
          [app_name, instance_name].filter(i => i).join('.')
        );
      }

      const {
        implements_add_user,
        implements_list_users
      } = clusterSelfResponse.authParams;

      menuFilter.set(clusterSelfResponse.MenuBlacklist);
      window.tarantool_enterprise_core.dispatch('dispatchToken', { type: '' });

      if (implements_add_user || implements_list_users) {
        window.tarantool_enterprise_core.dispatch(
          'dispatchToken',
          {
            type: 'ADD_CLUSTER_USERS_MENU_ITEM',
            payload: {
              location: window.tarantool_enterprise_core.history.location
            }
          }
        );
      }

      response = {
        ...clusterSelfResponse
      };
    } catch (error) {
      yield put({ type: APP_DATA_REQUEST_ERROR, error, requestPayload, __errorMessage: false });
      indicator.error();
      return undefined;
    }

    yield put({ type: APP_DATA_REQUEST_SUCCESS, payload: response, requestPayload });
    indicator.success();
  });
};

function* getActiveDeadServerMessage() {
  const messages = yield select(state => state.app.messages);
  return messages.find(
    message => message.type === SERVER_NOT_REACHABLE_ERROR_TYPE && !message.done
  );
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
          type: SERVER_NOT_REACHABLE_ERROR_TYPE
        };
        yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

        window.tarantool_enterprise_core.notify({
          title: 'An error has occurred',
          message: messageText,
          details: action.error.extensions ? action.error.extensions['io.tarantool.errors.stack'] : null,
          type: messageType,
          timeout: 0
        });
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
          content: { type: messageType, text: messageText }
        };
        yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

        window.tarantool_enterprise_core.notify({
          title: 'An error has occurred',
          message: messageText,
          details: action.error.extensions ? action.error.extensions['io.tarantool.errors.stack'] : null,
          type: messageType,
          timeout: 0
        });
      }
    }

    if (action.__successMessage) {
      const messageText = action.__successMessage;
      const messageType = 'success';

      const messagePayload = {
        content: { type: messageType, text: messageText }
      };
      yield put({ type: APP_CREATE_MESSAGE, payload: messagePayload });

      window.tarantool_enterprise_core.notify({
        title: 'Successful!',
        message: messageText,
        type: messageType,
        timeout: 5000
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

export const saga = baseSaga(
  appDataRequestSaga,
  appMessageSaga,
  doneMessage,
);
