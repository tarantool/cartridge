import { createStore, applyMiddleware, compose } from 'redux';
import { createLogger as createLoggerMiddleware } from 'redux-logger';
import createSagaMiddleware from 'redux-saga';

import rootReducer from './rootReducer';
import rootSaga from './rootSaga';

const composeEnhancers = window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__ || compose

const sagaMiddleware = createSagaMiddleware();
const loggerMiddleware = createLoggerMiddleware({ collapsed: true });

export default function configureStore(initialState) {
  const store = createStore(
    rootReducer,
    initialState,
    composeEnhancers(applyMiddleware(sagaMiddleware, loggerMiddleware))
  );

  sagaMiddleware.run(rootSaga);
  return store;
}

