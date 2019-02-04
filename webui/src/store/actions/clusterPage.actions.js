import {
  CLUSTER_PAGE_DID_MOUNT,
  CLUSTER_PAGE_SERVER_LIST_ROW_SELECT,
  CLUSTER_PAGE_SERVER_POPUP_CLOSE,
  CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT,
  CLUSTER_PAGE_REPLICASET_POPUP_CLOSE,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST,
  CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_STATE_RESET,
  SET_BOOSTRAP_VSHARD_MODAL_VISIBLE,
  SET_FAILOVER_MODAL_VISIBLE,
} from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

/**
 * @param {Object} payload
 * @param {string} payload.selectedServerUri
 * @param {string} payload.selectedReplicasetUuid
 */
export const pageDidMount = getPageMountActionCreator(CLUSTER_PAGE_DID_MOUNT);

export const selectServer = getActionCreator(CLUSTER_PAGE_SERVER_LIST_ROW_SELECT);

export const closeServerPopup = getActionCreator(CLUSTER_PAGE_SERVER_POPUP_CLOSE);

export const selectReplicaset = getActionCreator(CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT);

export const closeReplicasetPopup = getActionCreator(CLUSTER_PAGE_REPLICASET_POPUP_CLOSE);

export const bootstrapVshard = getActionCreator(CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST, null, {
  successMessage: 'VShard bootstrap is OK. Please wait for list refresh...',
});

/**
 * @param {Object} payload
 * @param {string} payload.uri
 */
export const probeServer = getActionCreator(CLUSTER_PAGE_PROBE_SERVER_REQUEST, null, {
  successMessage: 'Probe is OK. Please wait for list refresh...',
});

/**
 * @param {Object} payload
 * @param {string} payload.uri
 * @param {string} payload.uuid
 */
export const joinServer = getActionCreator(CLUSTER_PAGE_JOIN_SERVER_REQUEST, null, {
  successMessage: 'Join is OK. Please wait for list refresh...',
});

/**
 * @param {Object} payload
 * @param {string} payload.uri
 * @param {[string]} payload.roles
 */
export const createReplicaset = getActionCreator(CLUSTER_PAGE_CREATE_REPLICASET_REQUEST, null, {
  successMessage: 'Create is OK. Please wait for list refresh...',
});

/**
 * @param {Object} payload
 * @param {string} payload.uuid
 */
export const expelServer = getActionCreator(CLUSTER_PAGE_EXPEL_SERVER_REQUEST, null, {
  successMessage: 'Expel is OK. Please wait for list refresh...',
});

/**
 * @param {Object} payload
 * @param {string} payload.uuid
 * @param {string[]} payload.roles
 */
export const editReplicaset = getActionCreator(CLUSTER_PAGE_REPLICASET_EDIT_REQUEST, null, {
  successMessage: 'Edit is OK. Please wait for list refresh...',
});

export const uploadConfig = getActionCreator(CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST, null, {
  successMessage: 'Configuration uploaded successfully. Please wait for list refresh...',
});

export const applyTestConfig = getActionCreator(CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST, null, {
  successMessage: 'Configuration applied successfully. Please wait for list refresh...',
});

/*
 * @param {Object} params
 * @param {string} params.consoleKey
 * @param {object} params.consoleState
 */
export const resetPageState = getActionCreator(CLUSTER_PAGE_STATE_RESET);

/**
 * @param {Object} payload
 * @param {boolean} payload.enabled
 */
export const changeFailover = getActionCreator(CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST, null, {
  successMessage: 'Failover change is OK...',
});

export const setVisibleBootstrapVshardModal = visible => {
  return {
    type: SET_BOOSTRAP_VSHARD_MODAL_VISIBLE,
    payload: visible
  };
};

export const setVisibleFailoverModal = visible => {
  return {
    type: SET_FAILOVER_MODAL_VISIBLE,
    payload: visible
  };
}
