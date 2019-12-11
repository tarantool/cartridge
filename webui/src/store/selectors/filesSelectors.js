// @flow

import * as R from 'ramda';
import { createSelector } from 'reselect';

import type { FileItem } from '../reducers/files.reducer.js';

export type TreeFileItem = FileItem & {
  items: Array<TreeFileItem>
}
// export type TreeFileItem = {
//   fileId: string,
//   path: string,
//   fileName: string,
//   content?: string,
//   initialContent?: string,
//   type: 'file' | 'folder',
//   items: Array<TreeFileItem>
// }

const toTreeItem = (file: FileItem): TreeFileItem => ({ ...file, items: [] })

export const selectFileTree = (files: Array<FileItem>): Array<TreeFileItem> => {
  const newApproach = true;
  if (newApproach) {
    return v2_selectFileTree(files);
  }
  const fileMap: { [string]: TreeFileItem } = files.reduce(
    (r: { [string]: TreeFileItem }, x: FileItem) => {
      r[x.fileId] = toTreeItem(x);
      return r;
    },
    {}
  )
  const rootFiles = []
  for (const fileId in fileMap) {
    const f = fileMap[fileId]
    if (f.parentId) {
      fileMap[f.parentId].items.push(f)
    } else {
      rootFiles.push(f)
    }
  }
  return rootFiles

}


const makeFile = (name, path, isFolder = false, content = '', prevFileProps = {}) => {
  const newPath = `${path}${path ? '/' : ''}${name}`;
  return {
    // different fields for folders and files
    ...(
      isFolder ?
        {
          items: [],
          saved: true,
        } :
        {
          content: content,
          initialContent: content,
          loading: false,
          saved: true,
          column: 0,
          line: 0,
          scrollPosition: 0,
          ...prevFileProps,
        }
    ),

    path: newPath,
    fileName: name,
    type: isFolder ? 'folder' : 'file',
    fileId: newPath,//@deprecated  
  }
};

const cmpByFileName = (a, b) => (
  a.fileName < b.fileName && -1
  ||
  a.fileName > b.fileName && 1
  ||
  0
);

const cmpByType = (a, b) => {
  if (a.type === 'folder' && b.type === 'file')
    return -1;
  if (a.type === 'file' && b.type === 'folder')
    return 1;
  return 0;
}

const cmpByTypeAndFileName = (a, b) => {
  const cmpByTypeResult = cmpByType(a, b);
  if (cmpByTypeResult === 0) {
    return cmpByFileName(a, b);
  }
  return cmpByTypeResult;
};

const sortTree = tree => {
  tree.sort(cmpByTypeAndFileName);
  tree.forEach(folder => {
    folder.items && sortTree(folder.items);
  });
  return tree;
};

export const v2_selectFileTree = createSelector(
  [
    state => state,
  ],
  (files: Array<FileItem>): Array<TreeFileItem> => {
    const fileMap: { [string]: TreeFileItem } = files.reduce(
      (tree, file) => {
        tree[file.path] = toTreeItem(file);
        return tree;
      },
      {}
    );

    const rootFiles = []
    for (const fileId in fileMap) {
      const f = fileMap[fileId]
      if (f.parentPath) {
        fileMap[f.parentPath].items.push(f)
      } else {
        rootFiles.push(f)
      }
    }
    return sortTree(rootFiles);
  }
);

export const v2_OLD_selectFileTree = (files: Array<FileItem>): Array<TreeFileItem> => {
  return files.reduce((tree, file) => {
    const chain = file.path.split('/');

    let currentTreeItems = tree;
    let currentPathPart = '';
    chain.forEach((folderName, index) => {

      //@TODO: it's dirty. Let's enrich data with type='file' when fetching from API
      let isFolder = true;
      if (index === chain.length - 1 && file.type !== 'folder') {
        isFolder = false;
      }

      let curFolder = currentTreeItems.find(item => item.fileName === folderName);
      if (!curFolder) {
        // the last item in chain is file, others are folders
        curFolder = makeFile(folderName, currentPathPart, isFolder, file.content, file);
        currentTreeItems.push(curFolder);
      }

      // change variable ref
      currentTreeItems = curFolder.items;
      currentPathPart = curFolder.path;
    });
    return tree;
  }, []);
};


export const selectSelectedFile = createSelector(
  [
    state => state.files,
    state => state.editor.selectedFile
  ],
  (files, selectedFile) => {
    if (!selectedFile)
      return null
    for (const f of files) {
      if (f.path === selectedFile) {
        return makeFile(f.path, '', false, f.content, f)
      }
    }
    return null
  }
)
