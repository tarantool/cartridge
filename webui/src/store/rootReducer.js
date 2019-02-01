import { combineReducers } from 'redux';

// module path A-Z sorted
import { reducer as appReducer } from 'src/store/reducers/app.reducer';
import { reducer as clusterPageReducer } from 'src/store/reducers/clusterPage.reducer';
import ui from 'src/store/reducers/ui.reducer';

// object keys A-Z sorted
const rootReducer = combineReducers({
  app: appReducer,
  clusterPage: clusterPageReducer,
  ui,
});

export default rootReducer;
