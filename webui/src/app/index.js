import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import { appDidMount, setMessageDone } from 'src/store/actions/app.actions';
import App from './App';

const mapStateToProps = state => {
  const {
    app: {
      appMount,
      appDataRequestStatus,
      appDataRequestErrorMessage,
      clusterSelf,
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
    messages,
  };
};

const dispatchToProps = {
  appDidMount,
  setMessageDone,
};

export default withRouter(connect(mapStateToProps, dispatchToProps)(App));
