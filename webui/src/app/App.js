import React from 'react';
import { Route, Switch } from 'react-router-dom';

import 'src/styles/base.scss';
import 'src/styles/app.css';
import 'src/styles/pages.css';
import 'src/styles/tables.css';
import 'src/styles/tight-scroll.css';
import 'src/styles/refactor-me.css';

import AppMessage from 'src/components/AppMessage';
import ClusterPage from 'src/pages/Cluster';
import ClusterInstancePage from 'src/pages/ClusterInstance';
import UsersPage from 'src/pages/Users';
import { PROJECT_NAME } from 'src/constants';

class App extends React.Component {
  render() {
    const {
      appDataRequestStatus,
      appDataRequestErrorMessage,
      authorizationRequired
    } = this.props;
    const isLoading = !appDataRequestStatus.loaded;

    return isLoading || authorizationRequired
      ? null
      : appDataRequestErrorMessage
        ? this.renderError()
        : this.renderApp();
  }

  renderApp = () => {
    const { messages, setMessageDone } = this.props;

    return (
      <React.Fragment>
        <Switch>
          <Route path={`/${PROJECT_NAME}/instance/:instanceUUID`} component={ClusterInstancePage} />
          <Route path={`/${PROJECT_NAME}/users`} component={UsersPage} />
          <Route component={ClusterPage} />
        </Switch>
        <AppMessage messages={messages} setMessageDone={setMessageDone} />
      </React.Fragment>
    );
  };

  renderError = () => {
    const { appDataRequestErrorMessage } = this.props;
    return (
      <pre>
        {appDataRequestErrorMessage.text
          ? JSON.stringify(appDataRequestErrorMessage.text, null, '  ')
          : 'Sorry, something went wrong'}
      </pre>
    );
  };
}

export default App;
