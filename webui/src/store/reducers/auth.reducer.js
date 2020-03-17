import { isGraphqlAccessDeniedError, getGraphqlErrorMessage } from 'src/api/graphql';

import {
  APP_DATA_REQUEST_ERROR,
  APP_DATA_REQUEST_SUCCESS,
  AUTH_ACCESS_DENIED,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_ERROR,
  AUTH_TURN_REQUEST_ERROR,
  AUTH_TURN_REQUEST,
  AUTH_TURN_REQUEST_SUCCESS,
  SET_AUTH_MODAL_VISIBLE,
  EXPECT_WELCOME_MESSAGE,
  SET_WELCOME_MESSAGE
} from 'src/store/actionTypes';

const initialState = {
  authorizationEnabled: false,
  authorized: false,
  username: null,
  loading: false,
  error: null,
  authModalVisible: false,
  welcomeMessageExpected: false,
  welcomeMessage: null
};

export function reducer(state = initialState, { type, payload, error }) {
  switch (type) {
    case APP_DATA_REQUEST_SUCCESS:
      return {
        ...state,
        authorizationEnabled: payload.authParams.enabled || false,
        authorized: !!payload.authParams.username,
        username: payload.authParams.username || null,
        loading: false,
        error: null
      };

    case AUTH_LOG_IN_REQUEST:
    case AUTH_LOG_OUT_REQUEST:
    case AUTH_TURN_REQUEST:
      return {
        ...state,
        loading: true,
        error: null
      }

    case AUTH_LOG_IN_REQUEST_ERROR:
    case AUTH_LOG_OUT_REQUEST_ERROR:
    case AUTH_TURN_REQUEST_ERROR:
    case APP_DATA_REQUEST_ERROR:
      return {
        ...state,
        loading: false,
        error: isGraphqlAccessDeniedError(error) ? null : (getGraphqlErrorMessage(error) || 'Request error')
      };

    case AUTH_LOG_IN_REQUEST_SUCCESS:
      return {
        ...state,
        authorized: payload.authorized,
        username: payload.username || null,
        loading: false,
        error: payload.error || null,
        authModalVisible: state.authModalVisible && !payload.authorized
      };

    case AUTH_LOG_OUT_REQUEST_SUCCESS:
      return {
        ...state,
        authorized: false,
        username: null,
        loading: false,
        error: null
      };

    case AUTH_TURN_REQUEST_SUCCESS:
      return {
        ...state,
        authorizationEnabled: payload.enabled,
        loading: false,
        error: error || null
      };

    case AUTH_ACCESS_DENIED:
      return {
        ...state,
        authorizationEnabled: true,
        authorized: false,
        username: null,
      };

    case SET_AUTH_MODAL_VISIBLE:
      return {
        ...state,
        error: null,
        authModalVisible: payload.visible
      };

    case EXPECT_WELCOME_MESSAGE:
      return {
        ...state,
        welcomeMessageExpected: payload.doExpect
      };

    case SET_WELCOME_MESSAGE:
      return {
        ...state,
        welcomeMessage: payload.text
      };

    default:
      return state;
  }
}
