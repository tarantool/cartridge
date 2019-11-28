// @flow

import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILE_CONTENT_DONE,
  FETCH_CONFIG_FILE_CONTENT_FAIL,
  FETCH_CONFIG_FILES_DONE,
  PUT_CONFIG_FILE_CONTENT,
  PUT_CONFIG_FILE_CONTENT_DONE,
  UPDATE_CONTENT,
  CREATE_FILE,
  CREATE_FOLDER,
  DELETE_FILE,
  DELETE_FOLDER,
  RENAME_FILE,
  RENAME_FOLDER,
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
  column: 0,
  line: 0,
  scrollPosition: 0,
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

const initialState: Array<FileItem> = require('./files.initialState').default;

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


const pickUnusedFileName = (list: Array<FileItem>, parentId, name) => {
  const siblings = list.filter(file => file.parentId === parentId);
  let possibleName = `${name}`;

  // TODO: if path is converted from name, we should check path uniquity separately
  while (siblings.filter(file => file.fileName === possibleName).length > 0) {
    possibleName = `${possibleName} NEW`;
  }
  return possibleName;
};

const pickFileId = (list: Array<FileItem>): string => {
  const maxId = list.reduce((maxId, file) => Math.max(file.fileId || 0, maxId), 0);
  return `${maxId + 1}`;
};

const getFile = (list: Array<FileItem>, id): FileItem | void => (
  list.find(file => file.fileId === id)
);

const isDescendant = (ownPath: string, parentPath: string) => {
  return ownPath.substring(0, parentPath.length) === parentPath;
};

const prepareNameForPath = name => {
  // TODO: implement. Or remove and let path be anything
  return name;
};

const makePath = (parentPath, name) => `${parentPath}${prepareNameForPath(name)}`;


const makeFile = (list: Array<FileItem>, parentId: string, name: string, isFolder = false): FileItem => {
  const unusedName = pickUnusedFileName(list, parentId, name);
  const parent = parentId ? getFile(list, parentId) : null;
  const parentPath = parent ? `${parent.path}/` : '';
  const newFile: FileItem = {
    fileId: pickFileId(list),
    path: makePath(parentPath, unusedName),
    fileName: unusedName,
    content: '',
    initialContent: '',
    loading: false,
    saved: true,
    type: isFolder ? 'folder' : 'file',
    column: 0,
    line: 0,
    scrollPosition: 0,
  };
  if (parentId) {
    newFile.parentId = parentId;
  }
  return newFile;
};

const renameFile = (list: Array<FileItem>, id, newName): Array<FileItem> => {
  const index = list.findIndex(file => file.fileId === id);
  if (index === -1) {
    return list;
  }

  const targetFile = list[index];
  const oldName = targetFile.fileName;

  // TODO: prevent names (and paths) collisions (or remove such prevention in createFile())
  if (oldName === newName) {
    return list;
  }

  const oldPath = targetFile.path;
  const newPath = makePath(
    oldPath.substring(0, oldPath.length - oldName.length),
    newName
  );

  return list.map(file => {
    // Change name and path of this file
    if (file.fileId === id) {
      return {
        ...file,
        // TODO: prevent names (and paths) collisions (or remove such prevention in createFile())
        fileName: `${newName}`,
        path: newPath,
      };
    }
    // Update paths of all descendants
    if (targetFile.type === 'folder') {
      if (isDescendant(file.path, oldPath)) {
        const pathTail = file.path.substring(oldPath.length);
        return {
          ...file,
          path: `${newPath}${pathTail}`,
        }
      }
    }
    return file;
  });
};


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

    case CREATE_FILE:
    case CREATE_FOLDER:
      if (payload) {
        return [
          ...state,
          makeFile(
            state,
            payload.parentId,
            payload.name,
            type === CREATE_FOLDER
          )
        ];
      }

    case RENAME_FILE:
    case RENAME_FOLDER:
      if (payload && payload.name && payload.id) {
        return renameFile(
          state,
          payload.id,
          payload.name,
        )
      }

    case DELETE_FILE:

    case DELETE_FOLDER:

  }
  return state
}
