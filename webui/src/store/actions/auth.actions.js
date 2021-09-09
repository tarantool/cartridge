import {
  AUTH_LOG_IN_REQUEST,
  AUTH_LOG_OUT_REQUEST,
  AUTH_TURN_REQUEST,
  EXPECT_WELCOME_MESSAGE,
  SET_AUTH_MODAL_VISIBLE,
  SET_WELCOME_MESSAGE,
} from 'src/store/actionTypes';
import { getActionCreator } from 'src/store/commonRequest';

export const logIn = getActionCreator(AUTH_LOG_IN_REQUEST);

export const logOut = getActionCreator(AUTH_LOG_OUT_REQUEST);

export const expectWelcomeMessage = (doExpect) => ({
  type: EXPECT_WELCOME_MESSAGE,
  payload: { doExpect },
});
export const setWelcomeMessage = (text) => ({
  type: SET_WELCOME_MESSAGE,
  payload: { text },
});

export const turnAuth = (enabled) => ({
  type: AUTH_TURN_REQUEST,
  payload: { enabled },
});

export const showAuthModal = () => ({
  type: SET_AUTH_MODAL_VISIBLE,
  payload: { visible: true },
});

export const hideAuthModal = () => ({
  type: SET_AUTH_MODAL_VISIBLE,
  payload: { visible: false },
});
