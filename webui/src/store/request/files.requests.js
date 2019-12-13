// @flow
import graphql from 'src/api/graphql';
import {
  setFilesMutation,
  getFilesQuery
} from './queries.graphql';
import type { FileItem } from '../reducers/files.reducer.js';

export const applyFiles = (files: Array<FileItem>) => graphql.mutate(setFilesMutation, { files });

export const getFiles = () => graphql.fetch(getFilesQuery).then(({ cluster: { config } }) => config);
