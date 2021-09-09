// @flow
import {
  APP_DATA_REQUEST,
  APP_DATA_REQUEST_ERROR,
  APP_DATA_REQUEST_SUCCESS,
  AUTH_ACCESS_DENIED,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_ERROR,
  AUTH_TURN_REQUEST_SUCCESS,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  FETCH_CONFIG_FILES,
  FETCH_CONFIG_FILES_DONE,
  FETCH_CONFIG_FILES_FAIL,
  HIDE_EXPEL_MODAL,
  PUT_CONFIG_FILES_CONTENT,
  PUT_CONFIG_FILES_CONTENT_DONE,
  PUT_CONFIG_FILES_CONTENT_FAIL,
  SET_BOOSTRAP_VSHARD_PANEL_VISIBLE,
  SET_FAILOVER_MODAL_VISIBLE,
  SET_PROBE_SERVER_MODAL_VISIBLE,
  SHOW_EXPEL_MODAL,
} from '../actionTypes';

export type UIState = {
  bootstrapPanelVisible: boolean,
  probeServerModalVisible: boolean,
  requestingBootstrapVshard: boolean,
  showFailoverModal: boolean,
  requestinFailover: boolean,
  fetchingAuth: boolean,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  expelModal: ?string,
};

const initialState: UIState = {
  bootstrapPanelVisible: false,
  probeServerModalVisible: false,
  requestingBootstrapVshard: false,
  showFailoverModal: false,
  requestinFailover: false,
  fetchingAuth: false,
  fetchingConfigFiles: false,
  puttingConfigFiles: false,
  expelModal: null,
};

export const reducer = (state: UIState = initialState, { type, payload }: FSA): UIState => {
  switch (type) {
    case SET_BOOSTRAP_VSHARD_PANEL_VISIBLE: {
      return {
        ...state,
        bootstrapPanelVisible: payload,
      };
    }

    case SET_FAILOVER_MODAL_VISIBLE: {
      return {
        ...state,
        showFailoverModal: payload,
      };
    }

    case SET_PROBE_SERVER_MODAL_VISIBLE:
      return {
        ...state,
        probeServerModalVisible: payload,
      };

    case CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS:
      return {
        ...state,
        probeServerModalVisible: false,
      };

    case CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS: {
      return {
        ...state,
        showFailoverModal: false,
      };
    }

    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST: {
      return {
        ...state,
        bootstrapPanelVisible: false,
        requestingBootstrapVshard: true,
      };
    }

    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS:
    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR: {
      return {
        ...state,
        bootstrapPanelVisible: true,
        requestingBootstrapVshard: false,
      };
    }

    case AUTH_ACCESS_DENIED:
    case APP_DATA_REQUEST_SUCCESS:
    case AUTH_LOG_IN_REQUEST_SUCCESS:
    case AUTH_LOG_OUT_REQUEST_SUCCESS:
    case AUTH_TURN_REQUEST_SUCCESS:
    case AUTH_LOG_IN_REQUEST_ERROR:
    case AUTH_LOG_OUT_REQUEST_ERROR:
    case AUTH_TURN_REQUEST_ERROR:
    case APP_DATA_REQUEST_ERROR:
      return {
        ...state,
        fetchingAuth: false,
      };

    case AUTH_LOG_IN_REQUEST:
    case AUTH_LOG_OUT_REQUEST:
    case AUTH_TURN_REQUEST:
    case APP_DATA_REQUEST:
      return {
        ...state,
        fetchingAuth: true,
      };

    case FETCH_CONFIG_FILES:
      return {
        ...state,
        fetchingConfigFiles: true,
      };

    case FETCH_CONFIG_FILES_DONE:
    case FETCH_CONFIG_FILES_FAIL:
      return {
        ...state,
        fetchingConfigFiles: false,
      };

    case PUT_CONFIG_FILES_CONTENT:
      return {
        ...state,
        puttingConfigFiles: true,
      };

    case PUT_CONFIG_FILES_CONTENT_DONE:
    case PUT_CONFIG_FILES_CONTENT_FAIL:
      return {
        ...state,
        puttingConfigFiles: false,
      };

    case SHOW_EXPEL_MODAL: {
      return {
        ...state,
        expelModal: payload,
      };
    }

    case HIDE_EXPEL_MODAL:
    case CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR:
    case CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS: {
      return {
        ...state,
        expelModal: null,
      };
    }

    default: {
      return state;
    }
  }
};
