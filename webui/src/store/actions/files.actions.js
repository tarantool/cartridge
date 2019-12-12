import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILES,
  UPDATE_CONTENT,
  PUT_CONFIG_FILE_CONTENT,
  CREATE_FILE,
  CREATE_FOLDER,
  RENAME_FILE,
  RENAME_FOLDER,
  DELETE_FILE,
  DELETE_FOLDER,
} from '../actionTypes'

export const fetchConfigFiles = ({
  type: FETCH_CONFIG_FILES
});

export const fetchConfigFileContent = file => ({
  type: FETCH_CONFIG_FILE_CONTENT,
  payload: { file }
});

export const updateFileContent = (fileId, content) => ({
  type: UPDATE_CONTENT,
  payload: {
    fileId,
    content
  }
})

export const applyFiles = () => ({
  type: PUT_CONFIG_FILE_CONTENT,
});

export const createFile = ({ parentPath, name }) => ({
  type: CREATE_FILE,
  payload: { parentPath, name },
});
export const createFolder = ({ parentPath, name }) => ({
  type: CREATE_FOLDER,
  payload: { parentPath, name },
})

export const renameFile = ({ id, name }) => ({
  type: RENAME_FILE,
  payload: { id, name },
})
export const renameFolder = ({ id, name }) => ({
  type: RENAME_FOLDER,
  payload: { id, name },
})

export const deleteFile = ({ id }) => ({
  type: DELETE_FILE,
  payload: { id },
})
export const deleteFolder = ({ id }) => ({
  type: DELETE_FOLDER,
  payload: { id },
})
