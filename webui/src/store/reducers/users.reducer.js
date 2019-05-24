import { getGraphqlErrorMessage } from 'src/api/graphql';

import {
  USER_ERROR_RESET,
  USER_STATE_RESET,
  USER_LIST_REQUEST,
  USER_LIST_REQUEST_SUCCESS,
  USER_LIST_REQUEST_ERROR,
  USER_ADD_REQUEST,
  USER_ADD_REQUEST_SUCCESS,
  USER_ADD_REQUEST_ERROR,
  USER_EDIT_REQUEST,
  USER_EDIT_REQUEST_SUCCESS,
  USER_EDIT_REQUEST_ERROR,
  USER_REMOVE_REQUEST,
  USER_REMOVE_REQUEST_SUCCESS,
  SET_ADD_USER_MODAL_VISIBLE,
  SET_EDIT_USER_MODAL_VISIBLE
} from 'src/store/actionTypes';

export const initialState = {
  items: [],
  queryError: null,
  mutationError: null
};

export const reducer = (state = initialState, { type, payload, error }) => {
  switch (type) {
    case USER_LIST_REQUEST:
      return {
        ...state,
        queryError: null
      };

    case USER_LIST_REQUEST_SUCCESS:
      return {
        ...state,
        items: payload.items,
        queryError: null
      };

    case USER_LIST_REQUEST_ERROR:
      return {
        ...state,
        queryError: getGraphqlErrorMessage(error)
      };

    case USER_ADD_REQUEST:
    case USER_REMOVE_REQUEST:
    case USER_EDIT_REQUEST:
      return {
        ...state,
        mutationError: null
      }

    case USER_ADD_REQUEST_SUCCESS:
    case USER_REMOVE_REQUEST_SUCCESS:
    case USER_EDIT_REQUEST_SUCCESS:
      return {
        ...state,
        mutationError: null
      }

    case USER_ADD_REQUEST_ERROR:
    case USER_EDIT_REQUEST_ERROR:
      return {
        ...state,
        mutationError: getGraphqlErrorMessage(error)
      }

    case SET_ADD_USER_MODAL_VISIBLE:
    case SET_EDIT_USER_MODAL_VISIBLE:
      return {
        ...state,
        mutationError: null
      }

    case USER_ERROR_RESET:
      return {
        ...state,
        queryError: null,
        mutationError: null
      }

    case USER_STATE_RESET:
      return initialState;

    default:
      return state;
  }
};
