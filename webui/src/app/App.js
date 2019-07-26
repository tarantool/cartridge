import React from 'react';
import { Route, Switch } from 'react-router-dom';
import { css } from 'emotion';

import 'src/styles/app.css';
import 'src/styles/tables.css';
import 'src/styles/tight-scroll.css';

import AppMessage from 'src/components/AppMessage';
import ClusterPage from 'src/pages/Cluster';
import ClusterInstancePage from 'src/pages/ClusterInstance';
import UsersPage from 'src/pages/Users';
import { PROJECT_NAME } from 'src/constants';

const styles = {
  app: css`
    min-height: 100%;
    background: #FAFAFA;
    padding: 0px 30px 0 30px;

    p {
      margin-top: 0;
    }

    p + p {
      margin-top: 1em;
    }
  `
};

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
      <div className={styles.app}>
        <Switch>
          <Route path={`/${PROJECT_NAME}/instance/:instanceUUID`} component={ClusterInstancePage} />
          <Route path={`/${PROJECT_NAME}/users`} component={UsersPage} />
          <Route component={ClusterPage} />
        </Switch>
        <AppMessage messages={messages} setMessageDone={setMessageDone} />
      </div>
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
