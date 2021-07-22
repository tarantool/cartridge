// @flow
import graphql from 'src/api/graphql';
import {
  setFilesMutation,
  getFilesQuery,
  validateFilesQuery
} from './queries.graphql';
import type { ConfigSectionInput } from 'src/generated/graphql-typing';
import type { FileItem } from '../reducers/files.reducer.js';

export const applyFiles = (files: Array<FileItem>) => graphql.mutate(setFilesMutation, { files });

export const getFiles = () => graphql.fetch(getFilesQuery).then(({ cluster: { config } }) => config);

export const validateFiles = (sections: ConfigSectionInput[]) => graphql.fetch(validateFilesQuery, { sections })
  .then(({ cluster: { validate_config } }) => validate_config);
