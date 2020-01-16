import React, { lazy, Suspense } from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from 'src/app';
import Users from 'src/pages/Users';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import NetworkErrorSplash from 'src/components/NetworkErrorSplash';
import LogInForm from 'src/components/LogInForm';
import store from 'src/store/instance'
import {
  appDidMount,
  setConnectionState
} from 'src/store/actions/app.actions';
import { logOut } from 'src/store/actions/auth.actions';
import { PROJECT_NAME } from './constants';
import { menuReducer } from './menu';
import ConfigManagement from 'src/pages/ConfigManagement';

const Code = lazy(() => import('src/pages/Code'));
const Schema = lazy(() => import('src/pages/Schema'));

const { tarantool_enterprise_core } = window;

const projectPath = path => `/${PROJECT_NAME}/${path}`;

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router history={tarantool_enterprise_core.history}>
          <Suspense fallback={'Loading...'}>
            <Switch>
              <Route path={projectPath('dashboard')} component={App} />
              <Route path={projectPath('configuration')} component={ConfigManagement} />
              <Route path={projectPath('users')} component={Users} />
              <Route path={projectPath('code')} component={Code} />
              <Route path={projectPath('schema')} component={Schema} />
            </Switch>
            <NetworkErrorSplash />
          </Suspense>
        </Router>
      </Provider>
    )
  }
}

tarantool_enterprise_core.register(
  PROJECT_NAME,
  menuReducer,
  Root,
  'react'
);

tarantool_enterprise_core.subscribe('cluster:logout', () => {
  store.dispatch(logOut());
});

store.dispatch(appDidMount());

tarantool_enterprise_core.setHeaderComponent(
  <Provider store={store}>
    <React.Fragment>
      <HeaderAuthControl />
      <LogInForm />
    </React.Fragment>
  </Provider>
);

function graphQLConnectionErrorHandler(response, next) {
  const { app: { connectionAlive } } = store.getState();
  if (connectionAlive && response.networkError) {
    store.dispatch(setConnectionState(false));
  } else if (!connectionAlive && !response.networkError) {
    store.dispatch(setConnectionState(true));
  }

  return next(response);
}

tarantool_enterprise_core.apiMethods.registerApolloHandler('afterware', graphQLConnectionErrorHandler);
tarantool_enterprise_core.apiMethods.registerApolloHandler('onError', graphQLConnectionErrorHandler);

function axiosConnectionErrorHandler(response, next) {
  const { app: { connectionAlive } } = store.getState();

  if (response instanceof Error && response.message.toLowerCase().indexOf('network error') === 0) {
    if (connectionAlive) {
      store.dispatch(setConnectionState(false));
    }
  } else if (!connectionAlive) {
    store.dispatch(setConnectionState(true));
  }

  return next(response);
}

tarantool_enterprise_core.apiMethods.registerAxiosHandler('responseError', axiosConnectionErrorHandler);
tarantool_enterprise_core.apiMethods.registerAxiosHandler('response', axiosConnectionErrorHandler);
