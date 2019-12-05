// @flow
import graphql from 'src/api/graphql';
import {
  setFilesMutation,
} from './queries.graphql';
import type { FileItem } from '../reducers/files.reducer.js';


export function applyFiles(updatedFiles: Array<FileItem>, deletedFiles) {
  //@TODO we are waiting for API
  return new Promise((resolve, reject) => {
    console.info('Applied!', { updatedFiles, deletedFiles });
    setTimeout(() => resolve('Applied!'), 500);
  });
  // return graphql.mutate(setFilesMutation, { updatedFiles, deletedFiles });
}
