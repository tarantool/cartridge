import './misc/analytics';
import './apiEndpoints';
import './models/init';

import React, { Suspense } from 'react';
import { Provider } from 'react-redux';
import { Route, Router, Switch } from 'react-router-dom';
import { core } from '@tarantool.io/frontend-core';
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

const { AppGate, setConnectionAliveEvent, setConnectionDeadEvent, authAccessDeniedEvent } = app;

const projectPath = (path) => `/${PROJECT_NAME}/${path}`;

class RootComponent extends React.Component {
  render() {
    return (
      <>
        <AppGate />
        <Provider store={store}>
          <Router history={core.history}>
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

core.registerModule({
  namespace: PROJECT_NAME,
  menu: menuReducer,
  RootComponent,
});

core.subscribe('cluster:logout', () => {
  store.dispatch(logOut());
});

core.subscribe('cluster:post_authorize_hooks', () => {
  store.dispatch(appDidMount());
});

core.subscribe('cluster:expect_welcome_message', () => {
  store.dispatch(expectWelcomeMessage(true));
});

core.subscribe('cluster:set_welcome_message', (text) => {
  store.dispatch(setWelcomeMessage(text));
  store.dispatch(expectWelcomeMessage(false));
});

store.dispatch(appDidMount());

core.setHeaderComponent(
  <Provider store={store}>
    <>
      <HeaderAuthControl />
      <LogInForm />
    </>
  </Provider>
);

function authReloadCallback() {
  core.dispatch('core:updateReactTreeKey');
}

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

core.apiMethods.registerApolloHandler('afterware', graphQLConnectionErrorHandler);
core.apiMethods.registerApolloHandler('onError', graphQLConnectionErrorHandler);
core.apiMethods.registerApolloHandler('onError', graphQLAuthErrorHandler);

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

core.apiMethods.registerAxiosHandler('responseError', axiosAuthErrorHandler);
core.apiMethods.registerAxiosHandler('responseError', axiosConnectionErrorHandler);
core.apiMethods.registerAxiosHandler('response', axiosConnectionErrorHandler);

core.subscribe('cluster:login:done', authReloadCallback);
core.subscribe('cluster:logout:done', authReloadCallback);

core.install();
