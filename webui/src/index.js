import './misc/analytics';
import './apiEndpoints';
import './models/init';

import React, { Suspense } from 'react';
import { Provider } from 'react-redux';
import { Route, Router, Switch } from 'react-router-dom';
import { SectionPreloader } from '@tarantool.io/ui-kit';

import { isGraphqlAccessDeniedError } from 'src/api/graphql';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import LogInForm from 'src/components/LogInForm';
import NetworkErrorSplash from 'src/components/NetworkErrorSplash';
import { isNetworkError } from 'src/misc/isNetworkError';
import { createLazySection } from 'src/misc/lazySection';
import { app } from 'src/models';
import ConfigManagement from 'src/pages/ConfigManagement';
import Dashboard from 'src/pages/Dashboard';
import Users from 'src/pages/Users';
import { appDidMount } from 'src/store/actions/app.actions';
import { expectWelcomeMessage, logOut, setWelcomeMessage } from 'src/store/actions/auth.actions';
import { AUTH_ACCESS_DENIED } from 'src/store/actionTypes';
import store from 'src/store/instance';

import { PROJECT_NAME } from './constants';
import { menuFilter, menuReducer } from './menu';

const Code = createLazySection(() => import('src/pages/Code'));

const { tarantool_enterprise_core } = window;
const { AppGate, setConnectionAliveEvent, setConnectionDeadEvent, authAccessDeniedEvent } = app;

const projectPath = (path) => `/${PROJECT_NAME}/${path}`;

class Root extends React.Component {
  render() {
    return (
      <>
        <AppGate />
        <Provider store={store}>
          <Router history={tarantool_enterprise_core.history}>
            <Suspense fallback={<SectionPreloader />}>
              <Switch>
                <Route path={projectPath('dashboard')} component={Dashboard} />
                <Route path={projectPath('configuration')} component={ConfigManagement} />
                <Route path={projectPath('users')} component={Users} />
                <Route path={projectPath('code')} component={Code} />
              </Switch>
              <NetworkErrorSplash />
            </Suspense>
          </Router>
        </Provider>
      </>
    );
  }
}

menuFilter.hideAll();

tarantool_enterprise_core.register(PROJECT_NAME, menuReducer, Root, 'react', null);

tarantool_enterprise_core.subscribe('cluster:logout', () => {
  store.dispatch(logOut());
});

tarantool_enterprise_core.subscribe('cluster:post_authorize_hooks', () => {
  store.dispatch(appDidMount());
});

tarantool_enterprise_core.subscribe('cluster:expect_welcome_message', () => {
  store.dispatch(expectWelcomeMessage(true));
});

tarantool_enterprise_core.subscribe('cluster:set_welcome_message', (text) => {
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
  if (response.networkError) {
    setConnectionDeadEvent();
  } else {
    setConnectionAliveEvent();
  }

  return next(response);
}

function graphQLAuthErrorHandler(response, next) {
  if ((response.networkError && response.networkError.statusCode === 401) || isGraphqlAccessDeniedError(response)) {
    store.dispatch({ type: AUTH_ACCESS_DENIED });
    authAccessDeniedEvent();
  }

  return next(response);
}

tarantool_enterprise_core.apiMethods.registerApolloHandler('afterware', graphQLConnectionErrorHandler);
tarantool_enterprise_core.apiMethods.registerApolloHandler('onError', graphQLConnectionErrorHandler);
tarantool_enterprise_core.apiMethods.registerApolloHandler('onError', graphQLAuthErrorHandler);

function axiosConnectionErrorHandler(response, next) {
  if (isNetworkError(response)) {
    setConnectionDeadEvent();
  } else {
    setConnectionAliveEvent();
  }

  return next(response);
}

function axiosAuthErrorHandler(error, next) {
  if (error.response && error.response.status === 401) {
    store.dispatch({ type: AUTH_ACCESS_DENIED });
    authAccessDeniedEvent();
  }

  return next(error);
}

tarantool_enterprise_core.apiMethods.registerAxiosHandler('responseError', axiosAuthErrorHandler);
tarantool_enterprise_core.apiMethods.registerAxiosHandler('responseError', axiosConnectionErrorHandler);
tarantool_enterprise_core.apiMethods.registerAxiosHandler('response', axiosConnectionErrorHandler);

tarantool_enterprise_core.install();
