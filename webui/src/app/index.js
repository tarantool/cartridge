import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import { setMessageDone } from 'src/store/actions/app.actions';
import App from './App';

const mapStateToProps = state => {
  const {
    app: {
      appMount,
      appDataRequestStatus,
      appDataRequestErrorMessage,
      clusterSelf,
      messages,
      authParams: {
        implements_check_password
      }
    },
    auth: {
      authorizationEnabled,
      authorized
    }
  } = state;

  return {
    appMount,
    appDataRequestStatus,
    appDataRequestErrorMessage,
    clusterSelf,
    authorizationRequired: implements_check_password && authorizationEnabled && !authorized,
    messages,
  };
};

const dispatchToProps = { setMessageDone };

export default withRouter(connect(mapStateToProps, dispatchToProps)(App));
