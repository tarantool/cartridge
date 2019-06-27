import {
  CLUSTER_INSTANCE_DID_MOUNT,
  CLUSTER_INSTANCE_DATA_REQUEST,
  CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_DATA_REQUEST_ERROR,
  CLUSTER_INSTANCE_REFRESH_REQUEST,
  CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR,
  CLUSTER_INSTANCE_STATE_RESET
} from 'src/store/actionTypes';
import { baseReducer, getInitialRequestStatus, getPageMountReducer, getReducer, getRequestReducer }
  from 'src/store/commonRequest';

export const initialState = {
  alias: null,
  instanceUUID: null,
  message: null,
  status: null,
  uri: null,
  masterUUID: null,
  activeMasterUUID: null,
  roles: [],
  labels: [],
  pageDataRequestStatus: getInitialRequestStatus(),
  refreshRequestStatus: getInitialRequestStatus(),
  boxinfo: {
    network: {},
    general: {},
    replication: {},
    storage: {}
  },
  descriptions: {}
};

const pageMountReducer = getPageMountReducer(CLUSTER_INSTANCE_DID_MOUNT);

const pageDataRequestReducer = getRequestReducer(
  CLUSTER_INSTANCE_DATA_REQUEST,
  CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_DATA_REQUEST_ERROR,
  'pageDataRequestStatus',
);

const refreshRequestReducer = getRequestReducer(
  CLUSTER_INSTANCE_REFRESH_REQUEST,
  CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS,
  CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR,
  'refreshRequestStatus',
);


const pageStateResetReducer = getReducer(CLUSTER_INSTANCE_STATE_RESET, initialState);

export const reducer = baseReducer(
  initialState,
  pageMountReducer,
  pageDataRequestReducer,
  refreshRequestReducer,
  pageStateResetReducer,
)(
  (state, action) => {
    switch (action.type) {
      case CLUSTER_INSTANCE_DID_MOUNT:
        return {
          ...state,
          instanceUUID: action.payload.instanceUUID || null,
        };

      default:
        return state;
    }
  }
);
