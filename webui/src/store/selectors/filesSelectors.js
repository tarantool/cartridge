// @flow

import * as R from 'ramda';
import { createSelector } from 'reselect';

import type { FileItem } from '../reducers/files.reducer.js';

type TreeFileItem = FileItem & {
  items: Array<TreeFileItem>
}

const toTreeItem = (file: FileItem): TreeFileItem => ({ ...file, items: [] })

export const selectFileTree = (files: Array<FileItem>): Array<TreeFileItem> => {
  const fileMap:  {[string]: TreeFileItem} = files.reduce((r: {[string]: TreeFileItem}, x: FileItem) => {
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


export const selectSelectedFile = createSelector(
  [
    state => state.files,
    state => state.editor.selectedFile
  ],
  (files, selectedFile) => {
    if (!selectedFile)
      return null
    for (const f of files) {
      if (f.fileId === selectedFile) {
        return f
      }
    }
    return null
  }
)
