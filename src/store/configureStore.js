import { createStore, applyMiddleware } from 'redux';
import { createLogger as createLoggerMiddleware } from 'redux-logger';
import createSagaMiddleware from 'redux-saga';

import rootReducer from './rootReducer';
import rootSaga from './rootSaga';

const sagaMiddleware = createSagaMiddleware();
const loggerMiddleware = createLoggerMiddleware({ collapsed: true });

export default function configureStore(initialState) {
  const store = createStore(rootReducer, initialState, applyMiddleware(sagaMiddleware, loggerMiddleware));
  sagaMiddleware.run(rootSaga);
  return store;
}

