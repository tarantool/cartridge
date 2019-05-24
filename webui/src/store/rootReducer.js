import { combineReducers } from 'redux';

// module path A-Z sorted
import { reducer as appReducer } from 'src/store/reducers/app.reducer';
import { reducer as authReducer } from 'src/store/reducers/auth.reducer';
import { reducer as clusterPageReducer } from 'src/store/reducers/clusterPage.reducer';
import { reducer as clusterInstancePageReducer } from 'src/store/reducers/clusterInstancePage.reducer';
import { reducer as usersReducer } from 'src/store/reducers/users.reducer';
import ui from 'src/store/reducers/ui.reducer';

// object keys A-Z sorted
const rootReducer = combineReducers({
  app: appReducer,
  auth: authReducer,
  clusterPage: clusterPageReducer,
  clusterInstancePage: clusterInstancePageReducer,
  users: usersReducer,
  ui,
});

export default rootReducer;
