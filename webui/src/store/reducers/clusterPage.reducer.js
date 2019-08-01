// @flow
import {
  CLUSTER_PAGE_FILTER_SET,
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  CLUSTER_PAGE_SERVER_LIST_ROW_SELECT,
  CLUSTER_PAGE_SERVER_POPUP_CLOSE,
  CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT,
  CLUSTER_PAGE_REPLICASET_POPUP_CLOSE,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  CLUSTER_PAGE_STATE_RESET,
  SET_PROBE_SERVER_MODAL_VISIBLE
} from 'src/store/actionTypes';
import {
  baseReducer,
  getInitialRequestStatus,
  getPageMountReducer,
  getReducer,
  getRequestReducer
} from 'src/store/commonRequest';
import type { RequestStatusType } from 'src/store/commonTypes';
import type { Replicaset, Server, ServerStat } from 'src/generated/graphql-typing';
import { getErrorMessage } from 'src/api';

export type ServerStatWithUUID = {
  uuid: string,
  uri: string,
  statistics: ServerStat
};

export type ClusterPageState = {
  replicasetFilter: string,
  pageMount: boolean,
  pageDataRequestStatus: RequestStatusType,
  refreshListsRequestStatus: RequestStatusType,
  selectedServerUri: ?string,
  selectedReplicasetUuid: ?string,
  serverList: ?Server[],
  replicasetList: ?Replicaset[],
  serverStat: ?ServerStatWithUUID[],
  bootstrapVshardRequestStatus: RequestStatusType,
  // bootstrapVshardResponse: null,
  probeServerError: ?Error,
  probeServerRequestStatus: RequestStatusType,
  // probeServerResponse: null,
  joinServerRequestStatus: RequestStatusType,
  // joinServerResponse: null,
  createReplicasetRequestStatus: RequestStatusType,
  // createReplicasetResponse: null,
  expelServerRequestStatus: RequestStatusType,
  // expelSerrverResponse: null,
  editReplicasetRequestStatus: RequestStatusType,
  // editReplicasetResponse: null,
  uploadConfigRequestStatus: RequestStatusType,
  // uploadConfigResponse: null,
  applyTestConfigRequestStatus: RequestStatusType,
  // applyTestConfigResponse: null,
  changeFailoverRequestStatus: RequestStatusType,
  // changeFailoverResponse: null,
};

export const initialState: ClusterPageState = {
  replicasetFilter: '',
  pageMount: false,
  pageDataRequestStatus: getInitialRequestStatus(),
  refreshListsRequestStatus: getInitialRequestStatus(),
  selectedServerUri: null,
  selectedReplicasetUuid: null,
  serverList: null,
  replicasetList: null,
  serverStat: null,
  bootstrapVshardRequestStatus: getInitialRequestStatus(),
  bootstrapVshardResponse: null,
  probeServerError: null,
  probeServerRequestStatus: getInitialRequestStatus(),
  probeServerResponse: null,
  joinServerRequestStatus: getInitialRequestStatus(),
  joinServerResponse: null,
  createReplicasetRequestStatus: getInitialRequestStatus(),
  createReplicasetResponse: null,
  expelServerRequestStatus: getInitialRequestStatus(),
  expelSerrverResponse: null,
  editReplicasetRequestStatus: getInitialRequestStatus(),
  editReplicasetResponse: null,
  uploadConfigRequestStatus: getInitialRequestStatus(),
  uploadConfigResponse: null,
  applyTestConfigRequestStatus: getInitialRequestStatus(),
  applyTestConfigResponse: null,
  changeFailoverRequestStatus: getInitialRequestStatus(),
  changeFailoverResponse: null
};

const pageMountReducer = getPageMountReducer(CLUSTER_PAGE_DID_MOUNT);

const pageDataRequestReducer = getRequestReducer(
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  'pageDataRequestStatus',
);

const refreshListsRequestReducer = getRequestReducer(
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  'refreshListsRequestStatus',
);

const bootstrapVshardRequestReducer = getRequestReducer(
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  'bootstrapVshardRequestStatus',
);

const joinServerRequestReducer = getRequestReducer(
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  'joinServerRequestStatus',
);

const createReplicasetRequestReducer = getRequestReducer(
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  'createReplicasetRequestStatus',
);

const expelServerRequestReducer = getRequestReducer(
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  'joinServerRequestStatus',
);

const editReplicasetRequestReducer = getRequestReducer(
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  'replicasetEditResponse',
);

const uploadConfigRequestReducer = getRequestReducer(
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  'uploadConfigResponse',
);

const applyTestConfigRequestReducer = getRequestReducer(
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR,
  'applyTestConfigResponse',
);

const changeFailoverRequestReducer = getRequestReducer(
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  'changeFailoverRequestStatus',
);

const pageStateResetReducer = getReducer(CLUSTER_PAGE_STATE_RESET, initialState);

export const reducer = baseReducer(
  initialState,
  pageMountReducer,
  pageDataRequestReducer,
  refreshListsRequestReducer,
  bootstrapVshardRequestReducer,
  joinServerRequestReducer,
  createReplicasetRequestReducer,
  expelServerRequestReducer,
  editReplicasetRequestReducer,
  uploadConfigRequestReducer,
  applyTestConfigRequestReducer,
  changeFailoverRequestReducer,
  pageStateResetReducer,
)(
  (state: ClusterPageState, action): ClusterPageState => {
    switch (action.type) {
      case CLUSTER_PAGE_FILTER_SET:
        return {
          ...state,
          replicasetFilter: action.payload
        };

      case CLUSTER_PAGE_DID_MOUNT:
        return {
          ...state,
          selectedServerUri: action.payload.selectedServerUri || null,
          selectedReplicasetUuid: action.payload.selectedReplicasetUuid || null
        };

      case CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR:
        return {
          ...state,
          probeServerError: getErrorMessage(action.payload)
        };

      case CLUSTER_PAGE_PROBE_SERVER_REQUEST:
      case CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS:
      case SET_PROBE_SERVER_MODAL_VISIBLE:
        return {
          ...state,
          probeServerError: null
        }

      case CLUSTER_PAGE_SERVER_LIST_ROW_SELECT:
        return {
          ...state,
          selectedServerUri: action.payload.uri
        };

      case CLUSTER_PAGE_SERVER_POPUP_CLOSE:
        return {
          ...state,
          selectedServerUri: null
        };

      case CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT:
        return {
          ...state,
          selectedReplicasetUuid: action.payload.uuid
        };

      case CLUSTER_PAGE_REPLICASET_POPUP_CLOSE:
        return {
          ...state,
          selectedReplicasetUuid: null
        };

      default:
        return state;
    }
  }
);
