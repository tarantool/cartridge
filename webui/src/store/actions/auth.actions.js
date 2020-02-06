import {
  AUTH_TURN_REQUEST,
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_OUT_REQUEST,
  SET_AUTH_MODAL_VISIBLE,
  SET_WELCOME_MESSAGE
} from 'src/store/actionTypes';
import { getActionCreator } from 'src/store/commonRequest';

export const logIn = getActionCreator(AUTH_LOG_IN_REQUEST);

export const logOut = getActionCreator(AUTH_LOG_OUT_REQUEST);

export const setWelcomeMessage = text => ({
  type: SET_WELCOME_MESSAGE,
  payload: { text }
})

export const turnAuth = enabled => ({
  type: AUTH_TURN_REQUEST,
  payload: { enabled }
})

export const showAuthModal = () => ({
  type: SET_AUTH_MODAL_VISIBLE,
  payload: { visible: true }
});

export const hideAuthModal = () => ({
  type: SET_AUTH_MODAL_VISIBLE,
  payload: { visible: false }
});
