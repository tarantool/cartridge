import { isGraphqlAccessDeniedError } from 'src/api/graphql';
import { isRestAccessDeniedError } from 'src/api/rest';

import {
  AUTH_RESTORE,
  AUTH_SET_UNAUTHORIZED,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_IN_REQUEST_SUCCESS,
  AUTH_LOG_IN_REQUEST_ERROR,
  AUTH_LOG_OUT_REQUEST,
  AUTH_LOG_OUT_REQUEST_SUCCESS,
  AUTH_LOG_OUT_REQUEST_ERROR,
} from 'src/store/actionTypes';
import { AUTH_TURN_REQUEST_ERROR, AUTH_TURN_REQUEST, AUTH_TURN_REQUEST_SUCCESS } from '../actionTypes';

const initialState = {
  authorizationFeature: false,
  authorizationEnabled: false,
  authorized: false,
  username: null,
  loading: false,
  error: null
};

export function reducer(state = initialState, { type, payload, error }) {
  if (error && (isRestAccessDeniedError(error) || isGraphqlAccessDeniedError(error))) {
    return {
      ...state,
      authorizationFeature: true,
      authorizationEnabled: true,
      authorized: false,
      username: null,
      loading: false,
      error: null
    };
  }

  switch (type) {
    case AUTH_SET_UNAUTHORIZED:
      return {
        ...state,
        authorizationFeature: true,
        authorizationEnabled: true,
        authorized: false,
        username: null,
        error: null
      };

    case AUTH_RESTORE:
      return {
        ...state,
        authorizationFeature: true,
        authorizationEnabled: payload.enabled || false,
        authorized: !!payload.username,
        username: payload.username || null,
        error: null
      };

    case AUTH_LOG_IN_REQUEST:
    case AUTH_LOG_OUT_REQUEST:
    case AUTH_TURN_REQUEST:
      return {
        ...state,
        loading: true,
        error: null,
      }

    case AUTH_LOG_IN_REQUEST_ERROR:
    case AUTH_LOG_OUT_REQUEST_ERROR:
    case AUTH_TURN_REQUEST_ERROR:
      return {
        ...state,
        loading: false,
        error
      };

    case AUTH_LOG_IN_REQUEST_SUCCESS:
      return {
        ...state,
        authorized: payload.authorized,
        username: payload.username || null,
        loading: false,
        error: payload.error || null
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
        error: payload.error || null
      };

    default:
      return state;
  }
}
