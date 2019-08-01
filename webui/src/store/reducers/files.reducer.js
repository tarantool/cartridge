// @flow

import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILE_CONTENT_DONE,
  FETCH_CONFIG_FILE_CONTENT_FAIL,
  FETCH_CONFIG_FILES_DONE, PUT_CONFIG_FILE_CONTENT, PUT_CONFIG_FILE_CONTENT_DONE
} from "../actionTypes";

type FileItem = {
  parentId: string,
  fileId: string,
  path: string,
  fileName: string,
  content?: string,
  initialContent?: string,
  loading: boolean,
  saved: boolean,
}

type UpdateObj = {
  loading?: boolean,
  content?: string,
  saved?: boolean,
}

const toFileItem = (item): FileItem => {
  return {
    ...item,
    loading: false,
    saved: false,
  }
}

const initialState: Array<FileItem> = []

const updateFile = (fileList: Array<FileItem>, fileId: string, updateObj: UpdateObj): Array<FileItem> => {
  const updatedItems : Array<FileItem> = fileList.map(x => {
    return x.fileId === fileId ? {...x, ...updateObj} : x
  });
  return updatedItems
}

const updateAllFiles = (fileList: Array<FileItem>, updateObj: UpdateObj): Array<FileItem> => {
  const updatedItems : Array<FileItem> = fileList.map(x => {
    return {...x, ...updateObj}
  });
  return updatedItems
}

export default (state: Array<FileItem> = initialState, { type, payload }: FSA) => {
  switch(type) {
    case FETCH_CONFIG_FILES_DONE: {
      if (Array.isArray(payload))
        return payload.map(toFileItem)
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT: {
      if (payload && typeof(payload.fileId) === 'string')
        return updateFile(state, payload.fileId, { loading: true })
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT_DONE: {
      if (payload && typeof(payload.fileId) === 'string' && typeof(payload.content)) {
        return updateFile(state, payload.fileId, { loading: false, content: payload.content, initialContent: payload.content })
      }
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT_FAIL: {
      if (payload && typeof(payload.fileId) === 'string')
        return updateFile(state, payload.fileId, { loading: false })
      return state
    }
    case PUT_CONFIG_FILE_CONTENT_DONE: {
      return updateAllFiles(state, {saved: true})
    }
  }
  return state
}
