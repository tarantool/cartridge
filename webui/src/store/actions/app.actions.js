import {
  APP_DID_MOUNT,
  APP_SERVER_CONSOLE_EVAL_STRING_REQUEST,
  APP_SAVE_CONSOLE_STATE,
  APP_CREATE_MESSAGE,
  APP_SET_MESSAGE_DONE,
} from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

export const appDidMount = getPageMountActionCreator(APP_DID_MOUNT);

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
