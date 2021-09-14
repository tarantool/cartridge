// @flow

import { FETCH_CONFIG_FILES, FETCH_CONFIG_FILES_FAIL, SELECT_FILE } from '../actionTypes';

export type EditorState = {
  selectedFile: ?string,
  error: any,
};

const initialState: EditorState = {
  selectedFile: null,
  error: null,
};

// eslint-disable-next-line import/no-anonymous-default-export
export default (state: EditorState = initialState, { type, payload, error }: FSA): EditorState => {
  switch (type) {
    case SELECT_FILE: {
      if (payload) {
        return {
          ...state,
          selectedFile: payload,
        };
      }
      return state;
    }

    case FETCH_CONFIG_FILES_FAIL: {
      return {
        ...state,
        error,
      };
    }

    case FETCH_CONFIG_FILES: {
      return {
        ...state,
        error: null,
      };
    }
  }
  return state;
};
