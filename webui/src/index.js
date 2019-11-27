import React from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from 'src/app';
import Users from 'src/pages/Users';
import Code from 'src/pages/Code';
import Schema from 'src/pages/Schema';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import LogInForm from 'src/components/LogInForm';
import store from 'src/store/instance'
import { appDidMount } from 'src/store/actions/app.actions';
import { logOut } from 'src/store/actions/auth.actions';
import { PROJECT_NAME } from './constants';
import { menuReducer } from './menu';
import ConfigManagement from 'src/pages/ConfigManagement';

const projectPath = path => `/${PROJECT_NAME}/${path}`;

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <Router history={window.tarantool_enterprise_core.history}>
          <Switch>
            <Route path={projectPath('dashboard')} component={App} />
            <Route path={projectPath('configuration')} component={ConfigManagement} />
            <Route path={projectPath('users')} component={Users} />
            <Route path={projectPath('code')} component={Code} />
            <Route path={projectPath('schema')} component={Schema} />
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
