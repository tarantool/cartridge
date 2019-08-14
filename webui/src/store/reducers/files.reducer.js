// @flow

import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILE_CONTENT_DONE,
  FETCH_CONFIG_FILE_CONTENT_FAIL,
  FETCH_CONFIG_FILES_DONE,
  PUT_CONFIG_FILE_CONTENT,
  PUT_CONFIG_FILE_CONTENT_DONE, UPDATE_CONTENT
} from '../actionTypes';

export type FileItem = {
  parentId?: string,
  fileId: string,
  path: string,
  fileName: string,
  content?: string,
  initialContent?: string,
  loading: boolean,
  saved: boolean,
  type: 'file' | 'folder',
}

type UpdateObj = {
  loading?: boolean,
  content?: string,
  saved?: boolean | (FileItem, Object) => boolean,
}

const toFileItem = (item): FileItem => {
  return {
    ...item,
    loading: false,
    saved: false
  }
}

const initialState: Array<FileItem> = [
  {
    fileId: '1',
    path: 'config.yml',
    fileName: 'config.yml',
    content: `--- []
...
`,
    initialContent: `--- []
...
`,
    loading: false,
    saved: true,
    type: 'file'
  },
  {
    fileId: '2',
    path: 'app.lua',
    fileName: 'app.lua',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'file'
  },
  {
    fileId: '3',
    path: 'lib',
    fileName: 'lib',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'folder'
  },
  {
    parentId: '3',
    fileId: '4',
    path: 'lib/utils.lua',
    fileName: 'utils.lua',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'file'
  }
]

const updateFile = (
  fileList: Array<FileItem>,
  fileId: string,
  updateObj: UpdateObj,
  payload: Object = {},
): Array<FileItem> => {
  const updatedItems: Array<FileItem> = fileList.map(x => {
    const obj = {}
    for (const p in updateObj) {
      if (typeof updateObj[p] === 'function') {
        obj[p] = updateObj[p](x, payload)
      } else {
        obj[p] = updateObj[p]
      }
    }
    return x.fileId === fileId ? { ...x, ...obj } : x
  });
  return updatedItems
}

const updateAllFiles = (
  fileList: Array<FileItem>,
  updateObj: UpdateObj,
  payload: Object = {}
): Array<FileItem> => {
  const updatedItems: Array<FileItem> = fileList.map(x => {
    const obj = {}
    for (const p in updateObj) {
      if (typeof updateObj[p] === 'function') {
        obj[p] = updateObj[p](x, payload)
      } else {
        obj[p] = updateObj[p]
      }
    }
    return { ...x, ...obj }
  });
  return updatedItems
}

export default (state: Array<FileItem> = initialState, { type, payload }: FSA) => {
  switch (type) {
    case FETCH_CONFIG_FILES_DONE: {
      if (Array.isArray(payload))
        return payload.map(toFileItem)
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT: {
      if (payload && typeof (payload.fileId) === 'string')
        return updateFile(state, payload.fileId, { loading: true })
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT_DONE: {
      if (payload && typeof (payload.fileId) === 'string' && typeof (payload.content)) {
        return updateFile(
          state,
          payload.fileId,
          {
            loading: false,
            content: payload.content,
            initialContent: payload.content
          }
        )
      }
      return state
    }
    case FETCH_CONFIG_FILE_CONTENT_FAIL: {
      if (payload && typeof (payload.fileId) === 'string')
        return updateFile(state, payload.fileId, { loading: false })
      return state
    }
    case PUT_CONFIG_FILE_CONTENT_DONE: {
      return updateAllFiles(state, { saved: true })
    }
    case UPDATE_CONTENT: {
      if (payload && typeof (payload.fileId) === 'string' && typeof (payload.content) === 'string') {
        return updateFile(
          state,
          payload.fileId,
          {
            content: payload.content,
            saved: (item, payload) => item.initialContent === payload.content,
          },
          payload,
        )
      }
    }
  }
  return state
}
