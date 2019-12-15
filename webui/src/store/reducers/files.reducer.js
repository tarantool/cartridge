// @flow

import {
  FETCH_CONFIG_FILE_CONTENT,
  FETCH_CONFIG_FILE_CONTENT_DONE,
  FETCH_CONFIG_FILE_CONTENT_FAIL,
  FETCH_CONFIG_FILES_DONE,
  PUT_CONFIG_FILES_CONTENT,
  PUT_CONFIG_FILES_CONTENT_DONE,
  PUT_CONFIG_FILES_CONTENT_FAIL,
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
  parentPath: string,
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

export type FileList = Array<FileItem>;

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

const ignoreFiles = ['schema.yml']

const enrichFileList = (files: Array<any>) => {
  const pathToFileMap = {};
  files.forEach(file => {
    if (ignoreFiles.includes(file.path)) return;
    const parts = file.path.split('/');

    let currentItemPath = '';
    parts.forEach((itemName, index) => {
      const isFolder = index !== parts.length - 1;

      const parentPath = currentItemPath;
      currentItemPath = `${parentPath}${parentPath ? '/' : ''}${itemName}`;

      let item = pathToFileMap[currentItemPath];
      if (!item) {
        item = makeFile(parentPath, itemName, isFolder, file.content, { saved: true });
        pathToFileMap[currentItemPath] = item;
      }
    });
  });
  return Object.values(pathToFileMap);
};

const updateFile = (
  fileList: FileList,
  fileId: string,
  updateObj: UpdateObj,
  payload: Object = {},
): FileList => {
  const updatedItems: FileList = fileList.map(file => {
    const obj = {}
    for (const p in updateObj) {
      if (typeof updateObj[p] === 'function') {
        obj[p] = updateObj[p](file, payload)
      } else {
        obj[p] = updateObj[p]
      }
    }
    return file.fileId === fileId ? { ...file, ...obj } : file
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

const getUniqueId = (() => {
  let i = 1;
  return (): string => `${i++}`;
})();

const makeFile = (parentPath: string, name: string, isFolder = false, content = '', prevFileProps = {}): FileItem => {
  const selfPath = `${parentPath}${parentPath ? '/' : ''}${name}`;
  return {
    // different fields for folders and files
    ...(
      isFolder ?
        {
          saved: false,
          items: [],
        } :
        {
          saved: false,
          content: content,
          initialContent: content,
          loading: false,
          column: 0,
          line: 0,
          scrollPosition: 0,
        }
    ),
    ...prevFileProps,
    parentPath: parentPath,
    path: selfPath,
    fileId: getUniqueId(),
    fileName: name,
    type: isFolder ? 'folder' : 'file',
  }
};

const validatePathName = (list: Array<FileItem>, path: string) => {
  if (list.some(file => file.path === path && !file.deleted)) {
    return false;
  }
  return true;
};

const addFileOrFolder = (list: Array<FileItem>, { parentPath, name }: { parentPath: string, name: string }, type) => {
  const newPath = makePath(`${parentPath}${parentPath ? '/' : ''}`, name);

  if (!validatePathName(list, newPath)) {
    return list;
  }

  return [
    ...list,
    makeFile(parentPath || '', name, type === CREATE_FOLDER)
  ];
}

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

  if (!validatePathName(list, newPath)) {
    return list;
  }

  return list.map(file => {
    if (file.path === oldPath) {
      return {
        initialPath: file.path,
        ...file,
        path: newPath,
        fileName: newName
      };
    }
    return file;
  });
};

const replacePrefix = (str: string, oldPrefix: string, newPrefix: string) => {
  const tail = str.slice(oldPrefix.length);
  return `${newPrefix}${tail}`;
};

const renameFolder = (list: FileList, oldFolderPath: string, newName: string): FileList => {
  const newFolderPath = getRenamedPath(oldFolderPath, newName);
  if (newFolderPath === oldFolderPath) {
    return list;
  }

  if (!validatePathName(list, newFolderPath)) {
    return list;
  }

  return list.map(file => {
    if (file.path === oldFolderPath) {
      return {
        initialPath: file.path,
        ...file,
        path: newFolderPath,
        fileName: newName,
      }
    } else if (isDescendant(file.path, oldFolderPath)) {
      const pathTail = file.path.slice(oldFolderPath.length);
      return {
        initialPath: file.path,
        ...file,
        path: replacePrefix(file.path, oldFolderPath, newFolderPath),
        parentPath: replacePrefix(file.parentPath, oldFolderPath, newFolderPath),
      }
    }

    return file;
  });
};

const deleteFile = (list: Array<FileItem>, path): Array<FileItem> => (
  list.map(file => file.path === path ? { ...file, deleted: true } : file)
);

const deleteFolder = (list: Array<FileItem>, path): Array<FileItem> => (
  list.map(file => file.path === path || isDescendant(file.path, path) ? { ...file, deleted: true } : file)
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

export default (state: Array<FileItem> = [], { type, payload }: FSA) => {
  switch (type) {
    case FETCH_CONFIG_FILES_DONE: {
      if (Array.isArray(payload))
        return enrichFileList(payload)
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

    case PUT_CONFIG_FILES_CONTENT_DONE: {
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
        return addFileOrFolder(state, payload, type);
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
