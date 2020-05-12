// @flow
import {
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST,
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_ERROR,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_GET_REQUEST_ERROR,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_ERROR,
  CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_SUCCESS,
  CLUSTER_PAGE_SCHEMA_SET
} from 'src/store/actionTypes';
import { type schemaActions } from 'src/store/actions/schema.actions';

export type SchemaState = {
  savedValue: string,
  value: string,
  error: ?string,
  loading: boolean,
  uploading: boolean
};

export const initialState: SchemaState = {
  savedValue: '',
  value: '',
  error: null,
  loading: false,
  uploading: false
};

export const reducer = (state: SchemaState = initialState, action: schemaActions): SchemaState => {
  switch (action.type) {
    case CLUSTER_PAGE_SCHEMA_APPLY_REQUEST:
      return {
        ...state,
        uploading: true,
        error: null
      };

    case CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_SUCCESS:
      return {
        ...state,
        error: null,
        uploading: false
      };

    case CLUSTER_PAGE_SCHEMA_APPLY_REQUEST_ERROR:
      return {
        ...state,
        error: action.payload,
        uploading: false
      };

    case CLUSTER_PAGE_SCHEMA_GET_REQUEST:
      return {
        ...state,
        error: null,
        loading: false
      };

    case CLUSTER_PAGE_SCHEMA_GET_REQUEST_SUCCESS:
      return {
        ...state,
        savedValue: action.payload,
        value: action.payload,
        error: null,
        loading: false
      };

    case CLUSTER_PAGE_SCHEMA_GET_REQUEST_ERROR:
      return {
        ...state,
        error: action.payload,
        loading: false
      };

    case CLUSTER_PAGE_SCHEMA_SET:
      return {
        ...state,
        value: action.payload
      };

    case CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST:
      return {
        ...state,
        error: null
      };

    case CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_SUCCESS:
      return {
        ...state,
        error: action.payload
      };

    case CLUSTER_PAGE_SCHEMA_VALIDATE_REQUEST_ERROR:
      return {
        ...state,
        error: action.payload
      };

    default:
      return state;
  }
};
