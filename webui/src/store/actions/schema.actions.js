// @flow
import {
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST,
  CLUSTER_PAGE_SCHEMA_SET,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST
} from 'src/store/actionTypes';

export const getSchema = () => ({ type: CLUSTER_PAGE_SCHEMA_GET_REQUEST });
export type getSchemaActionCreator = typeof getSchema;
export type getSchemaAction = $Call<getSchemaActionCreator>;

export const applySchema = () => ({ type: CLUSTER_PAGE_SCHEMA_APPLY_REQUEST });
export type applySchemaActionCreator = typeof applySchema;
export type applySchemaAction = $Call<applySchemaActionCreator>;

export const setSchema = (schema: string) => ({ type: CLUSTER_PAGE_SCHEMA_SET, payload: schema });
export type setSchemaActionCreator = typeof setSchema;
export type setSchemaAction = $Call<setSchemaActionCreator, string>;

export const validateSchema = () => ({ type: CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST });
export type validateSchemaActionCreator = typeof validateSchema;
export type validateSchemaAction = $Call<validateSchemaActionCreator>;

export type schemaActions =
  | applySchemaAction
  | getSchemaAction
  | setSchemaAction;
