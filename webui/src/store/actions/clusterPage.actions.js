// @flow
import {
  CLUSTER_PAGE_FILTER_SET,
  CLUSTER_PAGE_MODAL_FILTER_SET,
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
  SET_BOOSTRAP_VSHARD_PANEL_VISIBLE,
  SET_FAILOVER_MODAL_VISIBLE,
  SET_PROBE_SERVER_MODAL_VISIBLE
} from 'src/store/actionTypes';
import { getActionCreator } from 'src/store/commonRequest';
import { HIDE_EXPEL_MODAL, SHOW_EXPEL_MODAL } from '../actionTypes';
import type {
  CreateReplicasetArgs,
  EditReplicasetArgs
} from '../request/clusterPage.requests';

/**
 * @param {Object} payload
 * @param {string} payload.selectedServerUri
 * @param {string} payload.selectedReplicasetUuid
 */
export const pageDidMount = (
  selectedServerUri: ?string,
  selectedReplicasetUuid: ?string
) => ({
  type: CLUSTER_PAGE_DID_MOUNT,
  payload: {
    selectedServerUri,
    selectedReplicasetUuid
  },
  __payload: {
    noErrorMessage: true
  }
});

export type PageDidMountActionCreator = typeof pageDidMount;
export type PageDidMountAction = $Call<PageDidMountActionCreator, string, string>;


export const selectServer = (uri: string) => ({
  type: CLUSTER_PAGE_SERVER_LIST_ROW_SELECT,
  payload: { uri }
});
export type SelectServerActionCreator = typeof selectServer;
export type SelectServerAction = $Call<SelectServerActionCreator, string>;


export const closeServerPopup = getActionCreator(CLUSTER_PAGE_SERVER_POPUP_CLOSE);


export const selectReplicaset = (uuid: string) => ({
  type: CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT,
  payload: {
    uuid
  }
});

export type SelectReplicasetActionCreator = typeof selectReplicaset;
export type SelectReplicasetAction = $Call<SelectReplicasetActionCreator, string>;


export const closeReplicasetPopup = getActionCreator(CLUSTER_PAGE_REPLICASET_POPUP_CLOSE);


export const bootstrapVshard = getActionCreator(CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST, null, {
  successMessage: 'VShard bootstrap is OK. Please wait for list refresh...'
});


/**
 * @param {Object} payload
 * @param {string} payload.uri
 */
export const probeServer = (uri: string) => ({
  type: CLUSTER_PAGE_PROBE_SERVER_REQUEST,
  payload: { uri },
  __payload: {
    successMessage: 'Probe is OK. Please wait for list refresh...'
  }
});

export type ProbeServerActionCreator = typeof probeServer;
export type ProbeServerAction = $Call<ProbeServerActionCreator, string>;


/**
 * @param {Object} payload
 * @param {string} payload.uri
 * @param {string} payload.uuid
 */
export const joinServer = (uri: string, uuid: string) => ({
  type: CLUSTER_PAGE_JOIN_SERVER_REQUEST,
  payload: {
    uri,
    uuid
  },
  __payload: {
    successMessage: 'Join is OK. Please wait for list refresh...'
  }
});

export type JoinServerActionCreator = typeof joinServer;
export type JoinServerAction = $Call<JoinServerActionCreator, string, string>;


export type CreateReplicasetAction = {
  type: 'CLUSTER_PAGE_CREATE_REPLICASET_REQUEST',
  payload: CreateReplicasetArgs
};

export type CreateReplicasetActionCreator = (p: CreateReplicasetArgs) => CreateReplicasetAction;
export const createReplicaset: CreateReplicasetActionCreator = getActionCreator(
  CLUSTER_PAGE_CREATE_REPLICASET_REQUEST,
  null,
  { successMessage: 'Create is OK. Please wait for list refresh...' }
);

/**
 * @param {Object} payload
 * @param {string} payload.uuid
 */
export const expelServer = getActionCreator(CLUSTER_PAGE_EXPEL_SERVER_REQUEST, null, {
  successMessage: 'Expel is OK. Please wait for list refresh...'
});

export const editReplicaset = (params: EditReplicasetArgs) => ({
  type: CLUSTER_PAGE_REPLICASET_EDIT_REQUEST,
  payload: params,
  __payload: {
    successMessage: 'Edit is OK. Please wait for list refresh...'
  }
});

export type EditReplicasetActionCreator = typeof editReplicaset;
export type EditReplicasetAction = $Call<EditReplicasetActionCreator, EditReplicasetArgs>;


export type UploadConfigAction = {
  type: 'CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST',
  payload: {
    data: FormData
  }
};

export type UploadConfigActionCreator = (data: { data: FormData }) => UploadConfigAction;

export const uploadConfig: UploadConfigActionCreator = getActionCreator(CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST, null, {
  noErrorMessage: true
});

export const applyTestConfig = getActionCreator(CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST, null, {
  successMessage: 'Configuration applied successfully. Please wait for list refresh...'
});

export type ResetPageStateAction = { type: 'CLUSTER_PAGE_STATE_RESET' };
export type ResetPageStateActionCreator = () => ResetPageStateAction;
export const resetPageState = getActionCreator(CLUSTER_PAGE_STATE_RESET);

/**
 * @param {Object} payload
 * @param {boolean} payload.enabled
 */
export const changeFailover = getActionCreator(CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST, null, {
  successMessage: 'Failover change is OK...'
});

export const setVisibleBootstrapVshardPanel = (visible: boolean) => {
  return {
    type: SET_BOOSTRAP_VSHARD_PANEL_VISIBLE,
    payload: visible
  };
};

export type setVisibleBootstrapVshardPanelActionCreator = typeof setVisibleBootstrapVshardPanel;
export type setVisibleBootstrapVshardPanelAction = $Call<setVisibleBootstrapVshardPanelActionCreator, boolean>;


export const setVisibleFailoverModal = (visible: boolean) => {
  return {
    type: SET_FAILOVER_MODAL_VISIBLE,
    payload: visible
  };
}

export const showExpelModal = (server: string) => {
  return {
    type: SHOW_EXPEL_MODAL,
    payload: server
  }
}

export const hideExpelModal = () => {
  return {
    type: HIDE_EXPEL_MODAL
  }
}

export type SetVisibleFailoverModalActionCreator = typeof setVisibleFailoverModal;
export type SetVisibleFailoverModalAction = $Call<SetVisibleFailoverModalActionCreator, boolean>;


export const setFilter = (query: string) => ({
  type: CLUSTER_PAGE_FILTER_SET,
  payload: query
});

export type SetFilterActionCreator = typeof setFilter;
export type SetFilterAction = $Call<SetFilterActionCreator, string>;


export const setModalFilter = (query: string) => ({
  type: CLUSTER_PAGE_MODAL_FILTER_SET,
  payload: query
});

export type SetModalFilterActionCreator = typeof setFilter;
export type SetModalFilterAction = $Call<SetFilterActionCreator, string>;


export const setProbeServerModalVisible = (visible: boolean) => ({
  type: SET_PROBE_SERVER_MODAL_VISIBLE,
  payload: visible
});

export type SetProbeServerModalVisibleActionCreator = typeof setProbeServerModalVisible;
export type SetProbeServerModalVisibleAction = $Call<SetProbeServerModalVisibleActionCreator, boolean>;
