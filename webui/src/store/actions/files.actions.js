import {
  FETCH_CONFIG_FILES,
  PUT_CONFIG_FILES_CONTENT,
  SET_IS_CONTENT_CHANGED,
  CREATE_FILE,
  CREATE_FOLDER,
  RENAME_FILE,
  RENAME_FOLDER,
  DELETE_FILE,
  DELETE_FOLDER
} from '../actionTypes'

export const fetchConfigFiles = (initial?: bool = false) => ({ type: FETCH_CONFIG_FILES, payload: { initial } });

export const setIsContentChanged = (fileId: string, isChanged: boolean) => ({
  type: SET_IS_CONTENT_CHANGED,
  payload: { fileId, isChanged }
})

export const applyFiles = () => ({ type: PUT_CONFIG_FILES_CONTENT });

export const createFile = ({ parentPath, name }) => ({
  type: CREATE_FILE,
  payload: { parentPath, name }
});
export const createFolder = ({ parentPath, name }) => ({
  type: CREATE_FOLDER,
  payload: { parentPath, name }
})

export const renameFile = ({ id, name }) => ({
  type: RENAME_FILE,
  payload: { id, name }
})
export const renameFolder = ({ id, name }) => ({
  type: RENAME_FOLDER,
  payload: { id, name }
})

export const deleteFile = ({ id }) => ({
  type: DELETE_FILE,
  payload: { id }
})
export const deleteFolder = ({ id }) => ({
  type: DELETE_FOLDER,
  payload: { id }
})
