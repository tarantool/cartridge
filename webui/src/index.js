import React from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from './app';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import configureStore from './store/configureStore';
import { logOut } from 'src/store/actions/auth.actions';
import { PROJECT_NAME } from './constants';
import { menuReducer } from './menu';

const projectPath = (path) => `/${PROJECT_NAME}/${path}`;

const store = configureStore();

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <div className="cluster_app cluster_prefix">
          <Router history={window.tarantool_enterprise_core.history}>
            <Switch>
              <Route path={projectPath('')} component={App} />
            </Switch>
          </Router>
        </div>
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


window.tarantool_enterprise_core.setHeaderComponent(
  <Provider store={store}>
    <HeaderAuthControl />
  </Provider>
);
