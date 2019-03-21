import { combineReducers } from 'redux';

// module path A-Z sorted
import { reducer as appReducer } from 'src/store/reducers/app.reducer';
import { reducer as clusterPageReducer } from 'src/store/reducers/clusterPage.reducer';
import { reducer as clusterInstancePageReducer } from 'src/store/reducers/clusterInstancePage.reducer';
import ui from 'src/store/reducers/ui.reducer';

// object keys A-Z sorted
const rootReducer = combineReducers({
  app: appReducer,
  clusterPage: clusterPageReducer,
  clusterInstancePage: clusterInstancePageReducer,
  ui,
});

export default rootReducer;
