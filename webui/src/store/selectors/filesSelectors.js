// @flow
import { createSelector } from 'reselect';

import type { CodeEditorState } from 'src/store/reducers/codeEditor.reducer';
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

const cmpByFileName = (a, b) => (
  (a.fileName < b.fileName && -1)
    || (a.fileName > b.fileName && 1)
    || 0
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

export const selectFileTree = createSelector(
  [
    (files: Array<FileItem>) => files
  ],
  (files: Array<FileItem>): Array<TreeFileItem> => {
    const fileMap: { [string]: TreeFileItem } = files.reduce(
      (tree, file) => {
        if (!file.deleted) tree[file.path] = toTreeItem(file);
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

export const selectSelectedFile = createSelector(
  [
    (codeEditorState: CodeEditorState) => codeEditorState.files,
    (codeEditorState: CodeEditorState) => codeEditorState.editor.selectedFile
  ],
  (files, selectedFile) => {
    if (!selectedFile)
      return null
    for (const f of files) {
      if (f.fileId === selectedFile) {
        return f;
      }
    }
    return null
  }
)

export const selectFilePaths = createSelector(
  [
    (files: Array<FileItem>) => files
  ],
  (files: Array<FileItem>): Array<string> => files.reduce(
    (acc, file) => {
      if (!file.deleted) acc.push(file.path);
      return acc;
    },
    []
  )
);
