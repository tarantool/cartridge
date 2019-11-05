import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILES,
  UPDATE_CONTENT,
  createFile,
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

export const createFileStart = ({ folderId }) => ({
  type: createFile.try,
  payload: {
    folderId,
  },
})


export const createFileDone = ({ folderId, name }) => ({
  type: createFile.done,
  payload: {
    folderId,
    name,
  },
})

export const createFileCancel = ({ folderId }) => ({
  type: createFile.fail,
  payload: {
    folderId,
  },
})
