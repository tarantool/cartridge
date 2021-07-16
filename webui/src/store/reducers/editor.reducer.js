// @flow

import { SELECT_FILE } from '../actionTypes';

export type EditorState = {
  selectedFile: ?string,
}

const initialState: EditorState = {
  selectedFile: null
}

export default (state: EditorState = initialState, { type, payload }: FSA): EditorState => {
  switch (type) {
    case SELECT_FILE: {
      if (payload) {
        return {
          ...state,
          selectedFile: payload
        }
      }
      return state
    }
  }
  return state
}
