import {
  AUTH_TURN_REQUEST,
  AUTH_RESTORE,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_OUT_REQUEST,
} from 'src/store/actionTypes';
import { getActionCreator } from 'src/store/commonRequest';

export const restoreAuthorization = ({ enabled, username }) => ({
  type: AUTH_RESTORE,
  payload: { enabled, username }
});

export const logIn = getActionCreator(AUTH_LOG_IN_REQUEST);

export const logOut = getActionCreator(AUTH_LOG_OUT_REQUEST);

export const turnAuth = enabled => ({
  type: AUTH_TURN_REQUEST,
  payload: { enabled }
})