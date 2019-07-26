import React from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from './app';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import LogInForm from 'src/components/LogInForm';
import configureStore from './store/configureStore';
import { appDidMount } from 'src/store/actions/app.actions';
import { logOut } from 'src/store/actions/auth.actions';
import { PROJECT_NAME } from './constants';
import { menuReducer } from './menu';

const projectPath = (path) => `/${PROJECT_NAME}/${path}`;

const store = configureStore();

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router history={window.tarantool_enterprise_core.history}>
          <Switch>
            <Route path={projectPath('')} component={App} />
          </Switch>
        </Router>
      </Provider>
    )
  }
}

window.tarantool_enterprise_core.register(
  PROJECT_NAME,
  menuReducer,
  Root,
  'react'
);

window.tarantool_enterprise_core.subscribe('cluster:logout', () => {
  store.dispatch(logOut());
});

store.dispatch(appDidMount());

window.tarantool_enterprise_core.setHeaderComponent(
  <Provider store={store}>
    <React.Fragment>
      <HeaderAuthControl />
      <LogInForm />
    </React.Fragment>
  </Provider>
);
