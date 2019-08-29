import React from 'react';
import { Route, Switch } from 'react-router-dom';

import 'src/styles/app.css';
import 'src/styles/tables.css';
import 'src/styles/tight-scroll.css';

import ClusterPage from 'src/pages/Cluster';
import PageLayout from 'src/components/PageLayout';
import { PROJECT_NAME } from 'src/constants';

const { AppTitle } = window.tarantool_enterprise_core.components;

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
      <PageLayout>
        <AppTitle title={'Cluster'}/>
        <Switch>
          <Route path={`/cluster/dashboard/instance/:instanceUUID`} component={ClusterPage} />
          <Route component={ClusterPage} />
        </Switch>
      </PageLayout>
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
