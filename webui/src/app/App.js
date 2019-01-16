import React from 'react';
import { Route } from 'react-router-dom';

import 'src/styles/bootstrap.css';
import 'src/styles/bootstrap/index.css';
import 'src/styles/base.scss';
import 'src/styles/app.css';
import 'src/styles/pages.css';
import 'src/styles/tables.css';
import 'src/styles/tight-scroll.css';
import 'src/styles/refactor-me.css';

import AppMessage from 'src/components/AppMessage';
import LoginForm from 'src/components/LoginForm';
import ClusterPage from 'src/pages/Cluster';

class App extends React.Component {
  componentDidMount() {
    const { appDidMount } = this.props;
    appDidMount();
  }

  render() {
    const { appDataRequestStatus, appDataRequestErrorMessage, authenticated } = this.props;
    const isLoading = ! appDataRequestStatus.loaded;

    return isLoading
      ? null
      : authenticated === false
        ? this.renderLoginForm()
        : appDataRequestErrorMessage
          ? this.renderError()
          : this.renderApp();
  }

  renderApp = () => {
    const { messages, setMessageDone } = this.props;

    return (
      <div className="app">
        <Route path="/" component={ClusterPage} />
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

  renderLoginForm = () => {
    const { loginResponse } = this.props;

    const submitMessage = loginResponse && loginResponse.message;

    return (
      <div>
        <LoginForm
          login={this.handleLoginClick}
          submitMessage={submitMessage} />
      </div>
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
