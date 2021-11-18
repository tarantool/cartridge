// @flow
import { getErrorMessage } from 'src/api';
import type { FailoverApi, Issue, Replicaset, Server, ServerStat } from 'src/generated/graphql-typing';
import {
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_REQUEST,
  CLUSTER_PAGE_FAILOVER_REQUEST_ERROR,
  CLUSTER_PAGE_FAILOVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FILTER_SET,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_MODAL_FILTER_SET,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT,
  CLUSTER_PAGE_REPLICASET_POPUP_CLOSE,
  CLUSTER_PAGE_SERVER_LIST_ROW_SELECT,
  CLUSTER_PAGE_SERVER_POPUP_CLOSE,
  CLUSTER_PAGE_STATE_RESET,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  SET_FAILOVER_MODAL_VISIBLE,
  SET_PROBE_SERVER_MODAL_VISIBLE,
} from 'src/store/actionTypes';
import {
  baseReducer,
  getInitialRequestStatus,
  getPageMountReducer,
  getReducer,
  getRequestReducer,
} from 'src/store/commonRequest';
import type { RequestStatusType } from 'src/store/commonTypes';

export type ServerStatWithUUID = {
  uuid: string,
  uri: string,
  statistics: ServerStat,
};

export type ClusterPageState = {
  issues: Issue[],
  replicasetFilter: string,
  modalReplicasetFilter: string,
  pageMount: boolean,
  pageDataRequestStatus: RequestStatusType,
  refreshListsRequestStatus: RequestStatusType,
  selectedServerUri: ?string,
  selectedReplicasetUuid: ?string,
  serverList: ?(Server[]),
  replicasetList: ?(Replicaset[]),

  failoverMode: ?string,
  failoverDataRequestStatus: RequestStatusType,
  failover_params: {
    mode: $PropertyType<FailoverApi, 'mode'>,
    tarantool_params: $PropertyType<FailoverApi, 'tarantool_params'>,
    state_provider: $PropertyType<FailoverApi, 'state_provider'>,
  },

  serverStat: ?(ServerStatWithUUID[]),
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
  // expelSerrerResponse: null,
  editReplicasetRequestStatus: RequestStatusType,
  // editReplicasetResponse: null,
  uploadConfigRequestStatus: RequestStatusType,
  applyTestConfigRequestStatus: RequestStatusType,
  // applyTestConfigResponse: null,
  changeFailoverRequestStatus: RequestStatusType,
};

export const initialState: ClusterPageState = {
  issues: [],
  replicasetFilter: '',
  modalReplicasetFilter: '',
  pageMount: false,
  pageDataRequestStatus: getInitialRequestStatus(),
  refreshListsRequestStatus: getInitialRequestStatus(),
  selectedServerUri: null,
  selectedReplicasetUuid: null,
  serverList: null,
  replicasetList: null,
  serverStat: null,

  failoverMode: null,
  failoverDataRequestStatus: getInitialRequestStatus(),
  failover_params: {
    mode: 'disabled',
    tarantool_params: null,
    state_provider: null,
  },

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
  expelServerResponse: null,
  editReplicasetRequestStatus: getInitialRequestStatus(),
  editReplicasetResponse: null,
  uploadConfigRequestStatus: getInitialRequestStatus(),
  applyTestConfigRequestStatus: getInitialRequestStatus(),
  applyTestConfigResponse: null,
  changeFailoverRequestStatus: getInitialRequestStatus(),
};

const pageMountReducer = getPageMountReducer(CLUSTER_PAGE_DID_MOUNT);

const pageDataRequestReducer = getRequestReducer(
  CLUSTER_PAGE_DATA_REQUEST,
  CLUSTER_PAGE_DATA_REQUEST_SUCCESS,
  CLUSTER_PAGE_DATA_REQUEST_ERROR,
  'pageDataRequestStatus'
);

const refreshListsRequestReducer = getRequestReducer(
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS,
  CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR,
  'refreshListsRequestStatus'
);

const bootstrapVshardRequestReducer = getRequestReducer(
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  'bootstrapVshardRequestStatus'
);

const joinServerRequestReducer = getRequestReducer(
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR,
  'joinServerRequestStatus'
);

const createReplicasetRequestReducer = getRequestReducer(
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR,
  'createReplicasetRequestStatus'
);

const expelServerRequestReducer = getRequestReducer(
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  'expelServerRequestStatus'
);

const editReplicasetRequestReducer = getRequestReducer(
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR,
  'replicasetEditResponse'
);

const uploadConfigRequestReducer = getRequestReducer(
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR,
  'uploadConfigRequestStatus'
);

const applyTestConfigRequestReducer = getRequestReducer(
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR,
  'applyTestConfigResponse'
);

const changeFailoverRequestReducer = getRequestReducer(
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR,
  'changeFailoverRequestStatus'
);

const getFailoverRequestReducer = getRequestReducer(
  CLUSTER_PAGE_FAILOVER_REQUEST,
  CLUSTER_PAGE_FAILOVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_REQUEST_ERROR,
  'failoverDataRequestStatus'
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
  getFailoverRequestReducer
)((state: ClusterPageState, action): ClusterPageState => {
  switch (action.type) {
    case CLUSTER_PAGE_FILTER_SET:
      return {
        ...state,
        replicasetFilter: action.payload,
      };

    case CLUSTER_PAGE_MODAL_FILTER_SET:
      return {
        ...state,
        modalReplicasetFilter: action.payload,
      };

    case CLUSTER_PAGE_DID_MOUNT:
      return {
        ...state,
        selectedServerUri: action.payload.selectedServerUri || null,
        selectedReplicasetUuid: action.payload.selectedReplicasetUuid || null,
      };

    case CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR:
      return {
        ...state,
        probeServerError: getErrorMessage(action.payload),
      };

    case CLUSTER_PAGE_PROBE_SERVER_REQUEST:
    case CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS:
    case SET_PROBE_SERVER_MODAL_VISIBLE:
      return {
        ...state,
        probeServerError: null,
      };

    case SET_FAILOVER_MODAL_VISIBLE:
      return {
        ...state,
        changeFailoverRequestStatus: {
          ...state.changeFailoverRequestStatus,
          error: null,
        },
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

    case CLUSTER_PAGE_FAILOVER_REQUEST_SUCCESS:
      return {
        ...state,
        failover_params: action.payload.cluster.failover_params,
      };

    default:
      return state;
  }
});
