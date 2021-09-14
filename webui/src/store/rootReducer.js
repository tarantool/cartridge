// @flow
import { combineReducers } from 'redux';

// module path A-Z sorted
import type { AppState } from 'src/store/reducers/app.reducer';
import { reducer as appReducer } from 'src/store/reducers/app.reducer';
import { reducer as authReducer } from 'src/store/reducers/auth.reducer';
import { reducer as clusterInstancePageReducer } from 'src/store/reducers/clusterInstancePage.reducer';
import type { ClusterPageState } from 'src/store/reducers/clusterPage.reducer';
import { reducer as clusterPageReducer } from 'src/store/reducers/clusterPage.reducer';
import type { CodeEditorState } from 'src/store/reducers/codeEditor.reducer';
import { default as codeEditorReducer } from 'src/store/reducers/codeEditor.reducer';
import type { UIState } from 'src/store/reducers/ui.reducer';
import { reducer as ui } from 'src/store/reducers/ui.reducer';

export type State = {
  app: AppState,
  clusterPage: ClusterPageState,
  ui: UIState,
  codeEditor: CodeEditorState,
  clusterInstancePage: Object,
};

// object keys A-Z sorted
const rootReducer = combineReducers({
  app: appReducer,
  auth: authReducer,
  clusterPage: clusterPageReducer,
  clusterInstancePage: clusterInstancePageReducer,
  ui,
  codeEditor: codeEditorReducer,
});

export default rootReducer;
