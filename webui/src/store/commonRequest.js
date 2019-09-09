import {
  all,
  call,
  put,
  takeEvery,
  takeLatest
} from 'redux-saga/effects';

import { pageRequestIndicator } from 'src/misc/pageRequestIndicator';

export function getInitialRequestStatus() {
  return {
    loading: false,
    loaded: false,
    error: null
  };
}

export function getLoadedRequestStatus() {
  return {
    loading: false,
    loaded: true,
    error: null
  };
}

export function getActionCreator(ACTION, payloadInject, __payloadInject) {
  return function actionCreator(payload, _payload) {
    return {
      type: ACTION,
      payload: {
        ...(payloadInject || {}),
        ...(payload || {})
      },
      __payload: {
        ...(__payloadInject || {}),
        ...(_payload || {})
      }
    };
  };
}

export function getPageMountActionCreator(ACTION, payloadInject, __payloadInject) {
  return getActionCreator(ACTION, payloadInject, { ...__payloadInject, noErrorMessage: true });
}

export function getReducer(ACTION, stateReducer) {
  return function reducer(state, action) {
    switch (action.type) {
      case ACTION:
        return typeof stateReducer === 'function'
          ? stateReducer(state, action)
          : {
            ...state,
            ...stateReducer
          };

      default:
        return state;
    }
  };
}

export function getPageMountReducer(PAGE_MOUNT) {
  return function resetStateReducer(state, action) {
    switch (action.type) {
      case PAGE_MOUNT:
        return {
          ...state,
          pageMount: true
        };

      default:
        return state;
    }
  };
}

export function getRequestReducer(REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, statusKey) {
  return function requestReducer(state, action) {
    switch (action.type) {
      case REQUEST:
        return {
          ...state,
          [statusKey]: {
            ...state[statusKey],
            loading: true,
            error: null
          }
        };

      case REQUEST_SUCCESS:
        return {
          ...state,
          ...action.payload,
          [statusKey]: {
            ...state[statusKey],
            loading: false,
            loaded: true
          }
        };

      case REQUEST_ERROR:
        return {
          ...state,
          [statusKey]: {
            ...state[statusKey],
            loading: false,
            loaded: true,
            error: action.error
          }
        };

      default:
        return state;
    }
  };
}

export function baseReducer(initialState, ...reducers) {
  return function createBaseReducer(customReducer) {
    return function baseReducers(state = initialState, action) {
      return reducers.reduce(
        (state, reducer) => reducer(state, action), customReducer ? customReducer(state, action) : state
      );
    };
  };
}

const createSaga = (effect, SIGNAL, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request) => {
  return function* sagaFlow() {
    yield effect(SIGNAL || REQUEST, function* load(action) {
      const {
        payload: requestPayload = {},
        __payload: {
          noIndicator,
          noErrorMessage,
          successMessage
        } = {}
      } = action;
      const indicator = noIndicator ? null : pageRequestIndicator.run();

      if (SIGNAL) {
        yield put({ type: REQUEST, payload: requestPayload });
      }

      let response;
      try {
        response = yield call(request, requestPayload);
        indicator && indicator.success();
      } catch (error) {
        yield put({
          type: REQUEST_ERROR,
          error,
          requestPayload,
          __errorMessage: !noErrorMessage
        });
        indicator && indicator.error();
        return;
      }

      yield put({
        type: REQUEST_SUCCESS, payload: response, requestPayload, __successMessage: successMessage
      });
    });
  };
};

export function getRequestSaga(REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request) {
  return createSaga(takeLatest, null, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request);
}

export function getConcurentRequestSaga(REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request) {
  return createSaga(takeEvery, null, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request);
}

export function getSignalRequestSaga(SIGNAL, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request) {
  return createSaga(takeLatest, SIGNAL, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request);
}

export function getConcurentSignalRequestSaga(SIGNAL, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request) {
  return createSaga(takeEvery, SIGNAL, REQUEST, REQUEST_SUCCESS, REQUEST_ERROR, request);
}

export function baseSaga(...sagas) {
  return function* baseSaga() {
    yield all(sagas.map(saga => saga()));
  };
}
