import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import { appDidMount, setMessageDone } from 'src/store/actions/app.actions';
import { logIn, logOut } from 'src/store/actions/auth.actions';
import App from './App';

const mapStateToProps = state => {
  const {
    app: {
      appMount,
      appDataRequestStatus,
      appDataRequestErrorMessage,
      clusterSelf,
      loginResponse,
      messages,
    },
    auth: {
      authorizationFeature,
      authorizationEnabled,
      authorized
    }
  } = state;

  return {
    appMount,
    appDataRequestStatus,
    appDataRequestErrorMessage,
    clusterSelf,
    authorizationRequired: authorizationFeature && authorizationEnabled && !authorized,
    loginResponse,
    messages,
  };
};

const dispatchToProps = {
  appDidMount,
  logIn,
  logOut,
  setMessageDone,
};

export default withRouter(connect(mapStateToProps, dispatchToProps)(App));
