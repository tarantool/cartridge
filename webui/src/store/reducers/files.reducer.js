// @flow
import { isDescendant } from 'src/misc/files.utils';

import {
  CREATE_FILE,
  CREATE_FOLDER,
  DELETE_FILE,
  DELETE_FOLDER,
  FETCH_CONFIG_FILES_DONE,
  RENAME_FILE,
  RENAME_FOLDER,
  SET_IS_CONTENT_CHANGED,
} from '../actionTypes';

export type ApiFileItem = {
  path: string,
  content: string,
};

export type FileItem = {
  fileId: string,
  path: string,
  initialPath?: string,
  parentPath: string,
  fileName: string,
  initialContent: string | null,
  saved: boolean,
  type: 'file' | 'folder',
  loading?: boolean,
  column?: 0,
  line?: 0,
  scrollPosition?: 0,
  deleted?: boolean,
};

export type FileList = Array<FileItem>;

type UpdateObj = {
  loading?: boolean,
  content?: string,
  saved?: boolean | ((FileItem, Object) => boolean),
};

const ignoreFiles = [];

const enrichFileList = (files: Array<ApiFileItem>, prevState: Array<FileItem> = []) => {
  const pathFileMap = {};
  files.forEach((file) => {
    // eslint-disable-next-line sonarjs/no-empty-collection
    if (ignoreFiles.includes(file.path)) return;
    const parts = file.path.split('/');

    let currentItemPath = '';
    parts.forEach((itemName, index) => {
      const isFolder = index !== parts.length - 1;

      const parentPath = currentItemPath;
      currentItemPath = `${parentPath}${parentPath ? '/' : ''}${itemName}`;

      let item = pathFileMap[currentItemPath];
      if (!item) {
        const localFile = prevState.find((localFile) => !localFile.deleted && localFile.path === currentItemPath);

        const propsToCopy = {
          saved: true,
          ...(localFile ? { fileId: localFile.fileId } : {}),
        };

        item = makeFile(parentPath, itemName, isFolder, file.content, propsToCopy);
        pathFileMap[currentItemPath] = item;
      }
    });
  });
  return Object.values(pathFileMap);
};

const updateFile = (fileList: FileList, fileId: string, updateObj: UpdateObj, payload: Object = {}): FileList => {
  const updatedItems: FileList = fileList.map((file) => {
    const obj = {};
    for (const p in updateObj) {
      if (typeof updateObj[p] === 'function') {
        obj[p] = updateObj[p](file, payload);
      } else {
        obj[p] = updateObj[p];
      }
    }
    return file.fileId === fileId ? { ...file, ...obj } : file;
  });
  return updatedItems;
};

const makePath = (parentPath, name) => `${parentPath}${name}`;

const getUniqueId = (() => {
  let i = 1;
  return (): string => `${i++}`;
})();

const makeFile = (
  parentPath: string,
  name: string,
  isFolder = false,
  initialContent = '',
  prevFileProps = {}
): FileItem => {
  const selfPath = `${parentPath}${parentPath ? '/' : ''}${name}`;

  const commonProps = {
    fileId: getUniqueId(),
    saved: false,
    ...prevFileProps,
    parentPath: parentPath,
    path: selfPath,
    fileName: name,
    type: isFolder ? 'folder' : 'file',
  };

  if (isFolder) {
    return {
      initialContent: null,
      items: [],
      ...commonProps,
    };
  } else {
    return {
      initialContent: initialContent,
      loading: false,
      column: 0,
      line: 0,
      scrollPosition: 0,
      ...commonProps,
    };
  }
};

const validatePathName = (list: Array<FileItem>, path: string) => {
  return !list.some((file) => file.path === path && !file.deleted);
};

const addFileOrFolder = (list: Array<FileItem>, parentPath: string, name: string, type) => {
  const newPath = makePath(`${parentPath}${parentPath ? '/' : ''}`, name);

  if (!validatePathName(list, newPath)) {
    return list;
  }

  return [...list, makeFile(parentPath || '', name, type === CREATE_FOLDER, null)];
};

const getFileNameFromPath = (path) => path.split('/').pop();

const getRenamedPath = (oldPath, newName) => {
  const oldName = getFileNameFromPath(oldPath);
  if (oldName === newName) {
    return oldPath;
  }
  return makePath(oldPath.slice(0, -oldName.length), newName);
};

const renameFile = (list: Array<FileItem>, oldPath, newName): Array<FileItem> => {
  const newPath = getRenamedPath(oldPath, newName);
  if (newPath === oldPath) {
    return list;
  }

  if (!validatePathName(list, newPath)) {
    return list;
  }

  return list.map((file) => {
    if (file.path === oldPath) {
      return {
        initialPath: file.path,
        ...file,
        path: newPath,
        fileName: newName,
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

  return list.map((file) => {
    if (file.path === oldFolderPath) {
      return {
        initialPath: file.path,
        ...file,
        path: newFolderPath,
        fileName: newName,
      };
    } else if (isDescendant(file.path, oldFolderPath)) {
      return {
        initialPath: file.path,
        ...file,
        path: replacePrefix(file.path, oldFolderPath, newFolderPath),
        parentPath: replacePrefix(file.parentPath, oldFolderPath, newFolderPath),
      };
    }

    return file;
  });
};

const deleteFile = (list: Array<FileItem>, path): Array<FileItem> =>
  list.map((file) => (file.path === path ? { ...file, deleted: true } : file));

const deleteFolder = (list: Array<FileItem>, path): Array<FileItem> =>
  list.map((file) => (file.path === path || isDescendant(file.path, path) ? { ...file, deleted: true } : file));

// const commitFilesChanges = (list: Array<FileItem>, filesForApi: Array<ApiFileItem> = []): Array<FileItem> => {
//   const newList = [];
//   list.forEach(file => {
//     //remove deleted files
//     if (file.deleted) {
//       return;
//     }
//
//     const fileForApi = filesForApi.find(fileForApi => fileForApi.path === file.path);
//     const initialContent = fileForApi ? fileForApi.content : file.initialContent;
//     //"commit" edits/renames in all files
//     newList.push({
//       ...file,
//       saved: true,
//       initialContent,
//       initialPath: file.path,
//     });
//   });
//   return newList;
// };

export default (state: Array<FileItem> = [], { type, payload }: FSA) => {
  switch (type) {
    case FETCH_CONFIG_FILES_DONE: {
      if (Array.isArray(payload)) return enrichFileList(payload, state);
      return state;
    }

    // case PUT_CONFIG_FILES_CONTENT_DONE: {
    // //TODO: Should we modify the state
    // // in case Apply succeeds (PUT_CONFIG_FILES_CONTENT_DONE),
    // // but consequent Fetch fails (FETCH_CONFIG_FILES_FAIL)?
    //   return commitFilesChanges(state, payload);
    // }

    case SET_IS_CONTENT_CHANGED:
      if (payload) {
        return updateFile(
          state,
          payload.fileId,
          {
            saved: !payload.isChanged,
          },
          payload
        );
      }
      break;

    case CREATE_FILE:
    case CREATE_FOLDER:
      if (payload && payload.name) {
        return addFileOrFolder(state, payload.parentPath, payload.name, type);
      }
      break;

    case RENAME_FILE:
      if (payload && payload.name && payload.id) {
        return renameFile(state, payload.id, payload.name);
      }
      break;

    case RENAME_FOLDER:
      if (payload && payload.name && payload.id) {
        return renameFolder(state, payload.id, payload.name);
      }
      break;

    case DELETE_FILE:
      if (payload && payload.id) {
        return deleteFile(state, payload.id);
      }
      break;
    case DELETE_FOLDER:
      if (payload && payload.id) {
        return deleteFolder(state, payload.id);
      }
      break;
  }
  return state;
};
