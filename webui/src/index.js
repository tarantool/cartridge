import React from 'react';
import { Provider } from 'react-redux';
import { Router, Switch, Route } from 'react-router-dom';
import App from './app';
import HeaderAuthControl from 'src/components/HeaderAuthControl';
import configureStore from './store/configureStore';

import { PROJECT_NAME } from './constants';

const projectPath = (path) => `/${PROJECT_NAME}/${path}`

const store = configureStore();

class Root extends React.Component {
  render() {
    return (
      <Provider store={store}>
        <div className="cluster_app">
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
  [
    {
      label: 'Cluster',
      path: `/${PROJECT_NAME}`
    },
  ],
  Root,
  'react'
);

window.tarantool_enterprise_core.setHeaderComponent(
  <Provider store={store}>
    <HeaderAuthControl />
  </Provider>
);
