// @flow
import { combineReducers } from 'redux';
import {
  DELETE_FOLDER,
  DELETE_FILE
} from 'src/store/actionTypes';
import { isDescendant } from 'src/misc/files.utils';
import { selectSelectedFile } from 'src/store/selectors/filesSelectors';

import { default as editor, type EditorState } from 'src/store/reducers/editor.reducer';
import { default as files, type FileList } from 'src/store/reducers/files.reducer';

export type CodeEditorState = {
  editor: EditorState,
  files: FileList,
};

const branchesReducer = combineReducers({
  files,
  editor
});

const currentLevelReducer = (state: CodeEditorState, { type, payload }: FSA) => {
  switch (type) {
    case DELETE_FOLDER:
    case DELETE_FILE:
      if (
        payload && payload.id
        &&
        state.editor.selectedFile
      ) {
        const deletingPath = payload.id;
        const selectedFile = selectSelectedFile(state);

        if (
          selectedFile.path === deletingPath
          ||
          isDescendant(selectedFile.path, deletingPath)
        ) {
          return {
            ...state,
            editor: {
              ...state.editor,
              selectedFile: null
            }
          }
        }
      }
      break;

    default:
      break;
  }
  return state;
};

const reducer = (state: CodeEditorState, action: FSA) => branchesReducer(
  currentLevelReducer(state, action),
  action
);

export default reducer;
