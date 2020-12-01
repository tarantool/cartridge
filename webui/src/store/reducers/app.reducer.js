// @flow
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
import type { Role, FailoverApi } from 'src/generated/graphql-typing';

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
  appDataRequestError: ?Error,
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
  failover_params: {
    mode: $PropertyType<FailoverApi, 'mode'>,
    tarantool_params: $PropertyType<FailoverApi, 'tarantool_params'>,
    state_provider: $PropertyType<FailoverApi, 'state_provider'>
  },
  messages: AppMessage[],
  authParams: {
    enabled?: boolean,
    implements_add_user?: boolean,
    implements_check_password?: boolean,
    implements_list_users?: boolean,
    implements_edit_user?: boolean,
    implements_remove_user?: boolean,
    username?: ?string
  },
};

const initialState: AppState = {
  appMount: false,
  appDataRequestStatus: getInitialRequestStatus(),
  appDataRequestError: null,
  clusterSelf: {},
  connectionAlive: true,
  failover_params: {
    mode: 'disabled',
    tarantool_params: null,
    state_provider: null
  },
  messages: [],
  authParams: {}
};

const appMountReducer = getReducer(APP_DID_MOUNT, { appMount: true });

const appDataRequestReducer = getRequestReducer(
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_SUCCESS,
  APP_DATA_REQUEST_ERROR,
  'appDataRequestStatus'
);

export const reducer = baseReducer(
  initialState,
  appMountReducer,
  appDataRequestReducer
)(
  (state: AppState, action): AppState => {
    switch (action.type) {
      case APP_DATA_REQUEST:
        return {
          ...state,
          appDataRequestError: null
        };

      case APP_DATA_REQUEST_ERROR: {
        const { error } = action;

        return {
          ...state,
          appDataRequestError: error
        };
      }

      case CLUSTER_SELF_UPDATE:
      case CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS:
      case CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS:
        return {
          ...state,
          clusterSelf: action.payload.clusterSelf,
          failover_params: action.payload.failover_params
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
            message => message.content === action.payload.content ? { ...message, done: true } : message
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
