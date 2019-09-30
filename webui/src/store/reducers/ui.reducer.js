import {
  SET_BOOSTRAP_VSHARD_PANEL_VISIBLE,
  SET_FAILOVER_MODAL_VISIBLE,
  CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR,
  CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS,
  CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS,
  AUTH_ACCESS_DENIED,
  APP_DATA_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_TURN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST_ERROR,
  AUTH_TURN_REQUEST_ERROR,
  APP_DATA_REQUEST_ERROR,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_OUT_REQUEST,
  AUTH_TURN_REQUEST,
  APP_DATA_REQUEST,
  SET_ADD_USER_MODAL_VISIBLE,
  SET_REMOVE_USER_MODAL_VISIBLE,
  SET_EDIT_USER_MODAL_VISIBLE,
  SET_PROBE_SERVER_MODAL_VISIBLE,
  USER_STATE_RESET,
  USER_LIST_REQUEST_SUCCESS,
  USER_LIST_REQUEST_ERROR,
  USER_ADD_REQUEST_ERROR,
  USER_EDIT_REQUEST_ERROR,
  USER_REMOVE_REQUEST_ERROR,
  USER_REMOVE_REQUEST_SUCCESS,
  USER_EDIT_REQUEST_SUCCESS,
  USER_ADD_REQUEST_SUCCESS,
  USER_LIST_REQUEST,
  USER_ADD_REQUEST,
  USER_REMOVE_REQUEST,
  USER_EDIT_REQUEST,
  SHOW_EXPEL_MODAL,
  HIDE_EXPEL_MODAL,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST,
  CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR,
  FETCH_CONFIG_FILES,
  FETCH_CONFIG_FILES_DONE,
  FETCH_CONFIG_FILES_FAIL,
  PUT_CONFIG_FILE_CONTENT,
  PUT_CONFIG_FILE_CONTENT_DONE,
  PUT_CONFIG_FILE_CONTENT_FAIL,
} from '../actionTypes';

export type UIState = {
  bootstrapPanelVisible: boolean,
  addUserModalVisible: boolean,
  editUserModalVisible: boolean,
  editUserId: ?string,
  probeServerModalVisible: boolean,
  removeUserModalVisible: boolean,
  removeUserId: ?string,
  requestingBootstrapVshard: boolean,
  showFailoverModal: boolean,
  requestinFailover: boolean,
  fetchingAuth: boolean,
  fetchingUserList: boolean,
  fetchingUserMutation: boolean,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  expelModal: ?string,
  expelError: ?string,
};

const initialState: UIState = {
  bootstrapPanelVisible: false,
  addUserModalVisible: false,
  editUserModalVisible: false,
  editUserId: null,
  probeServerModalVisible: false,
  removeUserModalVisible: false,
  removeUserId: null,
  requestingBootstrapVshard: false,
  showFailoverModal: false,
  requestinFailover: false,
  fetchingAuth: false,
  fetchingUserList: false,
  fetchingUserMutation: false,
  fetchingConfigFiles: false,
  puttingConfigFiles: false,
  expelModal: null,
  expelError: null
};

export const reducer = (state: UIState = initialState, { type, payload, error }: FSA): UIState => {
  switch (type) {
    case SET_BOOSTRAP_VSHARD_PANEL_VISIBLE: {
      return {
        ...state,
        bootstrapPanelVisible: payload
      }
    }

    case SET_FAILOVER_MODAL_VISIBLE: {
      return {
        ...state,
        showFailoverModal: payload
      }
    }

    case SET_PROBE_SERVER_MODAL_VISIBLE:
      return {
        ...state,
        probeServerModalVisible: payload
      }

    case CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS:
      return {
        ...state,
        probeServerModalVisible: false
      };

    case CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST: {
      return {
        ...state,
        showFailoverModal: false
      }
    }

    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST: {
      return {
        ...state,
        bootstrapPanelVisible: false,
        requestingBootstrapVshard: true
      }
    }

    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR: {
      return {
        ...state,
        bootstrapPanelVisible: true,
        requestingBootstrapVshard: false
      }
    }

    case CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS: {
      return {
        ...state,
        bootstrapPanelVisible: true,
        requestingBootstrapVshard: false
      }
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
        fetchingAuth: false
      };

    case AUTH_LOG_IN_REQUEST:
    case AUTH_LOG_OUT_REQUEST:
    case AUTH_TURN_REQUEST:
    case APP_DATA_REQUEST:
      return {
        ...state,
        fetchingAuth: true
      };

    case SET_ADD_USER_MODAL_VISIBLE:
      return {
        ...state,
        addUserModalVisible: payload.visible
      };

    case SET_REMOVE_USER_MODAL_VISIBLE:
      return {
        ...state,
        removeUserModalVisible: payload.visible,
        removeUserId: payload.visible ? payload.username : null
      };

    case SET_EDIT_USER_MODAL_VISIBLE:
      return {
        ...state,
        editUserModalVisible: payload.visible,
        editUserId: payload.visible ? payload.username : null
      };

    case USER_STATE_RESET:
      return {
        ...state,
        fetchingUserList: false,
        fetchingUserMutation: false
      };

    case USER_LIST_REQUEST_SUCCESS:
    case USER_LIST_REQUEST_ERROR:
      return {
        ...state,
        fetchingUserList: false
      };

    case USER_ADD_REQUEST_ERROR:
    case USER_EDIT_REQUEST_ERROR:
      return {
        ...state,
        fetchingUserMutation: false
      };

    case USER_REMOVE_REQUEST_ERROR:
    case USER_REMOVE_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        removeUserModalVisible: false,
        removeUserId: null
      };

    case USER_EDIT_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        editUserModalVisible: false,
        editUserId: null
      };

    case USER_ADD_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        addUserModalVisible: false
      };

    case USER_LIST_REQUEST:
      return {
        ...state,
        fetchingUserList: true
      };

    case USER_ADD_REQUEST:
    case USER_REMOVE_REQUEST:
    case USER_EDIT_REQUEST:
      return {
        ...state,
        fetchingUserMutation: true
      };

    case FETCH_CONFIG_FILES:
      return {
        ...state,
        fetchingConfigFiles: true
      };

    case FETCH_CONFIG_FILES_DONE:
    case FETCH_CONFIG_FILES_FAIL:
      return {
        ...state,
        fetchConfigFiles: false
      };

    case PUT_CONFIG_FILE_CONTENT:
      return {
        ...state,
        puttingConfigFiles: true
      }

    case PUT_CONFIG_FILE_CONTENT_DONE:
    case PUT_CONFIG_FILE_CONTENT_FAIL:
      return {
        ...state,
        puttingConfigFiles: false
      }

    case SHOW_EXPEL_MODAL: {
      return {
        ...state,
        expelModal: payload,
        expelError: null
      }
    }
    case CLUSTER_PAGE_EXPEL_SERVER_REQUEST: {
      return {
        ...state,
        expelError: null
      }
    }

    case CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR: {
      return {
        ...state,
        expelError: error.message
      }
    }

    case HIDE_EXPEL_MODAL:
    case CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS: {
      return {
        ...state,
        expelModal: null
      }
    }

    default: {
      return state;
    }
  }
};
