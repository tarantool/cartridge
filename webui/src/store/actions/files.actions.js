import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILES,
  UPDATE_CONTENT

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
