import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import { appDidMount, login, logout, setMessageDone } from 'src/store/actions/app.actions';
import App from './App';

const mapStateToProps = state => {
  const {
    app: {
      appMount,
      appDataRequestStatus,
      appDataRequestErrorMessage,
      clusterSelf,
      authenticated,
      loginResponse,
      messages,
    },
  } = state;

  return {
    appMount,
    appDataRequestStatus,
    appDataRequestErrorMessage,
    clusterSelf,
    authenticated,
    loginResponse,
    messages,
  };
};

const dispatchToProps = {
  appDidMount,
  login,
  logout,
  setMessageDone,
};

export default withRouter(connect(mapStateToProps, dispatchToProps)(App));
