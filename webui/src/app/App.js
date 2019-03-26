import React from 'react';
import { Route, Switch } from 'react-router-dom';

import 'src/styles/bootstrap.css';
import 'src/styles/bootstrap/index.css';
import 'src/styles/base.scss';
import 'src/styles/app.css';
import 'src/styles/my-antd.less';
import 'src/styles/pages.css';
import 'src/styles/tables.css';
import 'src/styles/tight-scroll.css';
import 'src/styles/refactor-me.css';

import AppMessage from 'src/components/AppMessage';
import LogInForm from 'src/components/LogInForm';
import ClusterPage from 'src/pages/Cluster';
import ClusterInstancePage from 'src/pages/ClusterInstance';
import { PROJECT_NAME } from 'src/constants';

class App extends React.Component {
  componentDidMount() {
    const { appDidMount } = this.props;
    appDidMount();
  }

  render() {
    const {
      appDataRequestStatus,
      appDataRequestErrorMessage,
      authorizationRequired
    } = this.props;
    const isLoading = !appDataRequestStatus.loaded;

    return isLoading
      ? null
      : authorizationRequired
        ? this.renderLoginForm()
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

  renderLoginForm = () => {
    const { loginResponse } = this.props;

    const submitMessage = loginResponse && loginResponse.message;

    return (
      <LogInForm
        login={this.handleLoginClick}
        submitMessage={submitMessage}
      />
    );
  };

  handleLoginClick = formData => {
    const { login } = this.props;
    login(formData);
  };

  handleLogoutClick = () => {
    const { logout } = this.props;
    logout();
  };
}

export default App;
