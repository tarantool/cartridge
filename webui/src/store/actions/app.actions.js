import {
  APP_DID_MOUNT,
  APP_LOGIN_REQUEST,
  APP_LOGOUT_REQUEST,
  APP_DENY_ANONYMOUS_REQUEST,
  APP_ALLOW_ANONYMOUS_REQUEST,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST,
  APP_SAVE_CONSOLE_STATE,
  APP_CREATE_MESSAGE,
  APP_SET_MESSAGE_DONE,
} from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

export const appDidMount = getPageMountActionCreator(APP_DID_MOUNT);

/**
 * @param {Object} payload
 * @param {string} payload.email
 * @param {string} payload.password
 */
export const login = getActionCreator(APP_LOGIN_REQUEST);

export const logout = getActionCreator(APP_LOGOUT_REQUEST);

export const denyAnonymous = getActionCreator(APP_DENY_ANONYMOUS_REQUEST);

export const allowAnonymous = getActionCreator(APP_ALLOW_ANONYMOUS_REQUEST);

/**
 * @param {Object} payload
 * @param {string} [payload.uri]
 * @param {string} payload.text
 */
export const evalString = getActionCreator(APP_SERVER_CONSOLE_EVAL_STRING_REQUEST);

/*
 * @param {Object} params
 * @param {string} params.consoleKey
 * @param {Object} params.consoleState
 */
export const saveConsoleState = getActionCreator(APP_SAVE_CONSOLE_STATE);
/*
 * @param {Object} payload
 * @param {Object} payload.content
 * @param {string} payload.content.type
 * @param {string} payload.content.text
 */
export const createMessage = getActionCreator(APP_CREATE_MESSAGE);

/*
 * @param {Object} payload
 * @param {number} payload.index
 */
export const setMessageDone = getActionCreator(APP_SET_MESSAGE_DONE);
