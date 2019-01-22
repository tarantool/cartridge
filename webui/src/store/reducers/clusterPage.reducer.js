import {
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
} from 'src/store/actionTypes';
import { baseReducer, getInitialRequestStatus, getPageMountReducer, getReducer, getRequestReducer }
  from 'src/store/commonRequest';

export const initialState = {
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
  changeFailoverResponse: null,
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

const probeServerRequestReducer = getRequestReducer(
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
  'probeServerRequestStatus',
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
  probeServerRequestReducer,
  joinServerRequestReducer,
  createReplicasetRequestReducer,
  expelServerRequestReducer,
  editReplicasetRequestReducer,
  uploadConfigRequestReducer,
  applyTestConfigRequestReducer,
  changeFailoverRequestReducer,
  pageStateResetReducer,
)(
  (state, action) => {
    switch (action.type) {
      case CLUSTER_PAGE_DID_MOUNT:
        return {
          ...state,
          selectedServerUri: action.payload.selectedServerUri || null,
          selectedReplicasetUuid: action.payload.selectedReplicasetUuid || null,
        };

      case CLUSTER_PAGE_SERVER_LIST_ROW_SELECT:
        return {
          ...state,
          selectedServerUri: action.payload.uri,
        };

      case CLUSTER_PAGE_SERVER_POPUP_CLOSE:
        return {
          ...state,
          selectedServerUri: null,
        };

      case CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT:
        return {
          ...state,
          selectedReplicasetUuid: action.payload.uuid,
        };

      case CLUSTER_PAGE_REPLICASET_POPUP_CLOSE:
        return {
          ...state,
          selectedReplicasetUuid: null,
        };

      default:
        return state;
    }
  }
);
