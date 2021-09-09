// @flow
import { combineReducers } from 'redux';

import { isDescendant } from 'src/misc/files.utils';
import { DELETE_FILE, DELETE_FOLDER } from 'src/store/actionTypes';
import type { EditorState } from 'src/store/reducers/editor.reducer';
import { default as editor } from 'src/store/reducers/editor.reducer';
import type { FileList } from 'src/store/reducers/files.reducer';
import { default as files } from 'src/store/reducers/files.reducer';
import { selectSelectedFile } from 'src/store/selectors/filesSelectors';

export type CodeEditorState = {
  editor: EditorState,
  files: FileList,
};

const branchesReducer = combineReducers({
  files,
  editor,
});

const currentLevelReducer = (state: CodeEditorState, { type, payload }: FSA) => {
  switch (type) {
    case DELETE_FOLDER:
    case DELETE_FILE:
      if (payload && payload.id && state.editor.selectedFile) {
        const deletingPath = payload.id;
        const selectedFile = selectSelectedFile(state);

        if (selectedFile.path === deletingPath || isDescendant(selectedFile.path, deletingPath)) {
          return {
            ...state,
            editor: {
              ...state.editor,
              selectedFile: null,
            },
          };
        }
      }
      break;

    default:
      break;
  }
  return state;
};

const reducer = (state: CodeEditorState, action: FSA) => branchesReducer(currentLevelReducer(state, action), action);

export default reducer;
