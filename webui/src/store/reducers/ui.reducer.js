import * as types from '../actionTypes'; // TOOD: refactor

const initialState = {
  showBootstrapModal: false,
  addUserModalVisible: false,
  editUserModalVisible: false,
  editUserId: null,
  removeUserModalVisible: false,
  removeUserId: null,
  requestingBootstrapVshard: false,
  showFailoverModal: false,
  requestinFailover: false,
  fetchingAuth: false,
  fetchingUserList: false,
  fetchingUserMutation: false,
};

export default (state = initialState, { type, payload }) => {
  switch (type) {
    case types.SET_BOOSTRAP_VSHARD_MODAL_VISIBLE: {
      return {
        ...state,
        showBootstrapModal: payload,
      }
    }

    case types.SET_FAILOVER_MODAL_VISIBLE: {
      return {
        ...state,
        showFailoverModal: payload,
      }
    }

    case types.CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST: {
      return {
        ...state,
        showFailoverModal: false,
      }
    }

    case types.CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST: {
      return {
        ...state,
        showBootstrapModal: false,
        requestingBootstrapVshard: true,
      }
    }

    case types.CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR: {
      return {
        ...state,
        requestingBootstrapVshard: false,
      }
    }

    case types.CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS: {
      return {
        ...state,
        requestingBootstrapVshard: false,
      }
    }

    case types.AUTH_ACCESS_DENIED:
    case types.APP_DATA_REQUEST_SUCCESS:
    case types.AUTH_LOG_IN_REQUEST_SUCCESS:
    case types.AUTH_LOG_OUT_REQUEST_SUCCESS:
    case types.AUTH_TURN_REQUEST_SUCCESS:
    case types.AUTH_LOG_IN_REQUEST_ERROR:
    case types.AUTH_LOG_OUT_REQUEST_ERROR:
    case types.AUTH_TURN_REQUEST_ERROR:
    case types.APP_DATA_REQUEST_ERROR:
      return {
        ...state,
        fetchingAuth: false
      };

    case types.AUTH_LOG_IN_REQUEST:
    case types.AUTH_LOG_OUT_REQUEST:
    case types.AUTH_TURN_REQUEST:
    case types.APP_DATA_REQUEST:
      return {
        ...state,
        fetchingAuth: true
      };

    case types.SET_ADD_USER_MODAL_VISIBLE:
      return {
        ...state,
        addUserModalVisible: payload.visible
      };

    case types.SET_REMOVE_USER_MODAL_VISIBLE:
      return {
        ...state,
        removeUserModalVisible: payload.visible,
        removeUserId: payload.visible ? payload.username : null
      };

    case types.SET_EDIT_USER_MODAL_VISIBLE:
      return {
        ...state,
        editUserModalVisible: payload.visible,
        editUserId: payload.visible ? payload.username : null
      };

    case types.USER_STATE_RESET:
      return {
        ...state,
        fetchingUserList: false,
        fetchingUserMutation: false
      };

    case types.USER_LIST_REQUEST_SUCCESS:
    case types.USER_LIST_REQUEST_ERROR:
      return {
        ...state,
        fetchingUserList: false
      };

    case types.USER_ADD_REQUEST_ERROR:
    case types.USER_EDIT_REQUEST_ERROR:
      return {
        ...state,
        fetchingUserMutation: false
      };

    case types.USER_REMOVE_REQUEST_ERROR:
    case types.USER_REMOVE_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        removeUserModalVisible: false,
        removeUserId: false
      };

    case types.USER_EDIT_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        editUserModalVisible: false,
        editUserId: null
      };

    case types.USER_ADD_REQUEST_SUCCESS:
      return {
        ...state,
        fetchingUserMutation: false,
        addUserModalVisible: false
      };

    case types.USER_LIST_REQUEST:
      return {
        ...state,
        fetchingUserList: true
      };

    case types.USER_ADD_REQUEST:
    case types.USER_REMOVE_REQUEST:
    case types.USER_EDIT_REQUEST:
      return {
        ...state,
        fetchingUserMutation: true
      };

    default: {
      return state;
    }
  }
};
