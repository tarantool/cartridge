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
  deleted?: boolean,
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

const newApproach = true;
const initialState: Array<FileItem> = require(`./files.initialState${newApproach ? '2' : ''}`).default;

const updateFile = (
  fileList: Array<FileItem>,
  path: string,
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
    return x.path === path ? { ...x, ...obj } : x
  });
  return updatedItems
}

const pickUnusedFileName = (list: Array<FileItem>, parentPath, name) => {
  const siblings = list.filter(file => isDescendant(file.path, parentPath));
  let possibleName = `${name}`;

  // TODO: if path is converted from name, we should check path uniquity separately
  while (siblings.some(file => file.fileName === possibleName)) {
    possibleName = `${possibleName} NEW`;
  }
  return possibleName;
};

const isDescendant = (ownPath: string, parentPath: string) => {
  return ownPath.substring(0, parentPath.length + 1) === `${parentPath}/`;
};

const makePath = (parentPath, name) => `${parentPath}${name}`;


const makeFile = (list: Array<FileItem>, parentPath: string, name: string, isFolder = false): FileItem => {
  const unusedName = pickUnusedFileName(list, parentPath, name);
  const newFile: FileItem = {
    path: makePath(parentPath ? `${parentPath}/` : '', unusedName),
    fileName: unusedName,
    content: '',
    initialContent: '',
    loading: false,
    saved: false,
    type: isFolder ? 'folder' : 'file',
    column: 0,
    line: 0,
    scrollPosition: 0,
  };
  return newFile;
};

const getFileNameFromPath = path => path.split('/').pop();

const getRenamedPath = (oldPath, newName) => {
  const oldName = getFileNameFromPath(oldPath);
  if (oldName === newName) {
    return oldPath;
  }
  return makePath(
    oldPath.slice(0, -oldName.length),
    newName
  );
};

const renameFile = (list: Array<FileItem>, oldPath, newName): Array<FileItem> => {
  const newPath = getRenamedPath(oldPath, newName);
  if (newPath === oldPath) {
    return list;
  }

  return list.map(file => {
    if (file.path === oldPath) {
      return {
        initialPath: file.path,
        ...file,
        path: newPath
      };
    }
    return file;
  });
};

const renameFolder = (list, oldFolderPath, newName) => {
  const newFolderPath = getRenamedPath(oldFolderPath, newName);
  if (newFolderPath === oldFolderPath) {
    return list;
  }

  return list.map(file => {
    if (isDescendant(file.path, oldFolderPath)) {
      const pathTail = file.path.slice(oldFolderPath.length);
      return {
        initialPath: file.path,
        ...file,
        path: `${newFolderPath}${pathTail}`,
      }
    }

    return file;
  });
};

const deleteFile = (list: Array<FileItem>, path): Array<FileItem> => (
  list.map(file => file.path === path ? { ...file, deleted: true, } : file)
);

const deleteFolder = (list: Array<FileItem>, path): Array<FileItem> => (
  list.map(file => isDescendant(file.path, path) ? { ...file, deleted: true, } : file)
);

const commitFilesChanges = (list: Array<FileItem>): Array<FileItem> => {
  const newList = [];
  list.forEach(file => {
    //remove deleted files
    if (file.deleted) {
      return;
    }
    //"commit" edits/renames in all files
    newList.push({
      ...file,
      saved: true,
      initialContent: file.content,
      initialPath: file.path,
    });
  });
  return newList;
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
      return commitFilesChanges(state);
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
      break;

    case RENAME_FILE:
      if (payload && payload.name && payload.id) {
        return renameFile(
          state,
          payload.id,
          payload.name,
        )
      }
      break;

    case RENAME_FOLDER:
      if (payload && payload.name && payload.id) {
        return renameFolder(
          state,
          payload.id,
          payload.name,
        )
      }
      break;

    case DELETE_FILE:
      if (payload && payload.id) {
        return deleteFile(
          state,
          payload.id,
        )
      }
      break;
    case DELETE_FOLDER:
      if (payload && payload.id) {
        return deleteFolder(
          state,
          payload.id,
        )
      }
      break;
  }
  return state
}
