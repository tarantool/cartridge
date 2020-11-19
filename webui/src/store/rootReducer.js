// @flow
import { combineReducers } from 'redux';

// module path A-Z sorted
import { reducer as appReducer, type AppState } from 'src/store/reducers/app.reducer';
import { reducer as authReducer } from 'src/store/reducers/auth.reducer';
import { reducer as clusterPageReducer, type ClusterPageState } from 'src/store/reducers/clusterPage.reducer';
import { reducer as clusterInstancePageReducer } from 'src/store/reducers/clusterInstancePage.reducer';
import { reducer as schemaReducer, type SchemaState } from 'src/store/reducers/schema.reducer';
import { default as codeEditorReducer, type CodeEditorState } from 'src/store/reducers/codeEditor.reducer';
import { reducer as ui, type UIState } from 'src/store/reducers/ui.reducer';

export type State = {
  app: AppState,
  clusterPage: ClusterPageState,
  schema: SchemaState,
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
  schema: schemaReducer,
  ui,
  codeEditor: codeEditorReducer
});

export default rootReducer;
