import * as types from '../actionTypes'; // TOOD: refactor

const initialState = {
  showBootstrapModal: false,
  requestingBootstrapVshard: false,
};

export default (state = initialState, {type, payload}) => {
  switch (type) {
    case types.SET_BOOSTRAP_VSHARD_MODAL_VISIBLE: {
      return {
        ...state,
        showBootstrapModal: payload,
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
    default: {
      return state;
    }
  }
};
