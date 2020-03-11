import React, { lazy, Suspense } from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from 'src/app';
import { isNetworkError } from 'src/misc/isNetworkError';
import Users from 'src/pages/Users';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import NetworkErrorSplash from 'src/components/NetworkErrorSplash';
import LogInForm from 'src/components/LogInForm';
import store from 'src/store/instance'
import {
  appDidMount,
  setConnectionState
} from 'src/store/actions/app.actions';
import {
  logOut,
  expectWelcomeMessage,
  setWelcomeMessage
} from 'src/store/actions/auth.actions';
import { PROJECT_NAME } from './constants';
import { menuReducer, menuFilter } from './menu';
import ConfigManagement from 'src/pages/ConfigManagement';
import DemoInfo from 'src/components/DemoInfo';
import './misc/analytics';
import { SectionPreloader } from 'src/components/SectionPreloader';
import { createLazySection } from 'src/misc/lazySection';

const Code = createLazySection(() => import('src/pages/Code'));
const Schema = createLazySection(() => import('src/pages/Schema'));

const { tarantool_enterprise_core } = window;

const projectPath = path => `/${PROJECT_NAME}/${path}`;

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router history={tarantool_enterprise_core.history}>
          <Suspense fallback={<SectionPreloader />}>
            <DemoInfo />
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
  'react',
  null,
  menuFilter.check
);

tarantool_enterprise_core.subscribe('cluster:logout', () => {
  store.dispatch(logOut());
});

tarantool_enterprise_core.subscribe('cluster:post_authorize_hooks', () => {
  store.dispatch(appDidMount());
});

tarantool_enterprise_core.subscribe('cluster:expect_welcome_message', () => {
  store.dispatch(expectWelcomeMessage(true));
});

tarantool_enterprise_core.subscribe('cluster:set_welcome_message', text => {
  store.dispatch(setWelcomeMessage(text));
  store.dispatch(expectWelcomeMessage(false));
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

  if (isNetworkError(response)) {
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
