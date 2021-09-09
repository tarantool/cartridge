import { applyMiddleware, compose, createStore } from 'redux';
import createSagaMiddleware from 'redux-saga';

import rootReducer from './rootReducer';
import rootSaga from './rootSaga';

const composeEnhancers = window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__ || compose;

const sagaMiddleware = createSagaMiddleware();

export default function configureStore(initialState) {
  const store = createStore(rootReducer, initialState, composeEnhancers(applyMiddleware(sagaMiddleware)));

  sagaMiddleware.run(rootSaga);
  return store;
}
