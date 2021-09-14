import {
  APP_CONNECTION_STATE_CHANGE,
  APP_CREATE_MESSAGE,
  APP_DID_MOUNT,
  APP_SET_MESSAGE_DONE,
} from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

export const appDidMount = getPageMountActionCreator(APP_DID_MOUNT);

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

export const setConnectionState = (alive) => ({ type: APP_CONNECTION_STATE_CHANGE, payload: alive });
