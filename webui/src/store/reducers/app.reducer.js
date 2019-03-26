import { isGraphqlErrorResponse } from 'src/api/graphql';
import { isRestErrorResponse } from 'src/api/rest';
import {
  APP_DID_MOUNT,
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_SUCCESS,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_ERROR,
  APP_SAVE_CONSOLE_STATE,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_STATE_RESET,
  APP_CREATE_MESSAGE,
  APP_SET_MESSAGE_DONE,
  CLUSTER_SELF_UPDATE,
} from 'src/store/actionTypes';
import { baseReducer, getInitialRequestStatus, getReducer, getRequestReducer } from 'src/store/commonRequest';

const beautifyJSON = json => JSON.stringify(json, null, '  ');

const isEvalError = message => /^---\nerror/.test(message);

const initialState = {
  appMount: false,
  appDataRequestStatus: getInitialRequestStatus(),
  appDataRequestErrorMessage: null,
  clusterSelf: null,
  failover: null,
  evalStringRequestStatus: getInitialRequestStatus(),
  evalStringResponse: null,
  evalResult: null,
  savedConsoleState: {},
  messages: [],
};

const appMountReducer = getReducer(APP_DID_MOUNT, { appMount: true });

const appDataRequestReducer = getRequestReducer(
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  'appDataRequestStatus',
);

const evalStringRequestReducer = getRequestReducer(
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_SUCCESS,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_ERROR,
  'evalStringRequestStatus',
);

export const reducer = baseReducer(
  initialState,
  appMountReducer,
  appDataRequestReducer,
  evalStringRequestReducer,
)(
  (state, action) => {
    switch (action.type) {
      case APP_DATA_REQUEST_ERROR: {
        const { error } = action;

        if (isRestErrorResponse(error)) {
          return {
            ...state,
            appDataRequestErrorMessage: {
              text: error.responseText,
            },
          };
        }

        if (isGraphqlErrorResponse(error)) {
          return {
            ...state,
            appDataRequestErrorMessage: {
              text: error,
            },
          };
        }

        return {
          ...state,
          appDataRequestErrorMessage: {},
        };
      }

      case APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_SUCCESS: {
        const output = action.payload.evalStringResponse;
        return {
          ...state,
          evalResult: {
            output,
            type: isEvalError(output) ? 'error' : 'success',
          },
        };
      }

      case APP_SERVER_CONSOLE_EVAL_STRING_REQUEST_ERROR:
        return {
          ...state,
          evalResult: {
            output: beautifyJSON(action.error),
            type: 'error',
          },
        };

      case CLUSTER_PAGE_STATE_RESET:
      case APP_SAVE_CONSOLE_STATE:
        if (action.payload.consoleState) {
          return {
            ...state,
            savedConsoleState: {
              ...state.savedConsoleState,
              [action.payload.consoleKey]: {
                state: action.payload.consoleState,
              },
            },
          };
        }
        else {
          return state;
        }

      case CLUSTER_SELF_UPDATE:
      case CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS:
        return {
          ...state,
          clusterSelf: action.payload.clusterSelf,
          failover: action.payload.failover,
        };

      case CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS:
        return {
          ...state,
          clusterSelf: action.payload.changeFailoverResponse.clusterSelf.clusterSelf,
          failover: action.payload.changeFailoverResponse.clusterSelf.failover,
        };

      case APP_CREATE_MESSAGE:
        return {
          ...state,
          messages: [...state.messages, { ...action.payload, done: false }],
        };

      case APP_SET_MESSAGE_DONE:
        return {
          ...state,
          messages: state.messages.map(
            message => message.content === action.payload.content ? { ...message, done: true } : message,
          ),
        };

      default:
        return state;
    }
  }
);
