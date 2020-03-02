// @flow
import { isGraphqlErrorResponse, isGraphqlAccessDeniedError } from 'src/api/graphql';
import { isRestErrorResponse, isRestAccessDeniedError } from 'src/api/rest';
import {
  APP_DID_MOUNT,
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  APP_CONNECTION_STATE_CHANGE,
  AUTH_ACCESS_DENIED,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  APP_CREATE_MESSAGE,
  APP_SET_MESSAGE_DONE,
  CLUSTER_SELF_UPDATE
} from 'src/store/actionTypes';
import {
  baseReducer,
  getInitialRequestStatus,
  getReducer,
  getRequestReducer
} from 'src/store/commonRequest';
import type { RequestStatusType } from 'src/store/commonTypes';
import type { Role } from 'src/generated/graphql-typing';

type AppMessage = {
  content: {
    type: string,
    text: string
  },
  done: boolean
};

export type AppState = {
  appMount: boolean,
  appDataRequestStatus: RequestStatusType,
  appDataRequestErrorMessage: null,
  clusterSelf: {
    uri: ?string,
    uuid: ?string,
    configured: ?boolean,
    knownRoles: ?Role[],
    can_bootstrap_vshard: ?boolean,
    vshard_bucket_count: ?number,
    demo_uri: ?string,
  },
  connectionAlive: boolean,
  failover: null,
  messages: AppMessage[],
  authParams: {
    enabled: ?false,
    implements_add_user: ?false,
    implements_check_password: ?false,
    implements_list_users: ?false,
    implements_edit_user: ?false,
    implements_remove_user: ?false,
    username: ?null
  },
};

const initialState: AppState = {
  appMount: false,
  appDataRequestStatus: getInitialRequestStatus(),
  appDataRequestErrorMessage: null,
  clusterSelf: {},
  connectionAlive: true,
  failover: null,
  messages: [],
  authParams: {}
};

const appMountReducer = getReducer(APP_DID_MOUNT, { appMount: true });

const appDataRequestReducer = getRequestReducer(
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  'appDataRequestStatus',
);

export const reducer = baseReducer(
  initialState,
  appMountReducer,
  appDataRequestReducer,
)(
  (state, action) => {
    switch (action.type) {
      case APP_DATA_REQUEST:
        return {
          ...state,
          appDataRequestErrorMessage: null
        };

      case APP_DATA_REQUEST_ERROR: {
        const { error } = action;

        if (isRestErrorResponse(error) && !isRestAccessDeniedError(error)) {
          return {
            ...state,
            appDataRequestErrorMessage: {
              text: error.responseText
            }
          };
        }

        if (isGraphqlErrorResponse(error) && !isGraphqlAccessDeniedError(error)) {
          return {
            ...state,
            appDataRequestErrorMessage: {
              text: error
            }
          };
        }

        return {
          ...state,
          appDataRequestErrorMessage: {}
        };
      }

      case CLUSTER_SELF_UPDATE:
      case CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS:
        return {
          ...state,
          clusterSelf: action.payload.clusterSelf,
          failover: action.payload.failover
        };

      case CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS:
        return {
          ...state,
          clusterSelf: action.payload.changeFailoverResponse.clusterSelf.clusterSelf,
          failover: action.payload.changeFailoverResponse.clusterSelf.failover
        };

      case APP_CREATE_MESSAGE:
        return {
          ...state,
          messages: [...state.messages, { ...action.payload, done: false }]
        };

      case APP_SET_MESSAGE_DONE:
        return {
          ...state,
          messages: state.messages.map(
            message => message.content === action.payload.content ? { ...message, done: true } : message,
          )
        };

      case AUTH_ACCESS_DENIED:
        return {
          ...state,
          authParams: {
            ...state.authParams,
            implements_check_password: true
          }
        };

      case APP_CONNECTION_STATE_CHANGE:
        return {
          ...state,
          connectionAlive: action.payload
        };

      default:
        return state;
    }
  }
);
