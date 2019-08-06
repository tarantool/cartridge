import { SELECT_FILE } from '../actionTypes';


export const selectFile = fileId => ({
  type: SELECT_FILE,
  payload: fileId
})
