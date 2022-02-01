import {
  APP_CREATE_MESSAGE,
  APP_DID_MOUNT,
  APP_RELOAD_CLUSTER_SELF,
  APP_SET_MESSAGE_DONE,
} from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

export const appDidMount = getPageMountActionCreator(APP_DID_MOUNT);

export const appReloadClusterSelf = getActionCreator(APP_RELOAD_CLUSTER_SELF);

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
