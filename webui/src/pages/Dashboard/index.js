import { connect } from 'react-redux';

import Dashboard from './Dashboard';

const mapStateToProps = (state) => {
  const {
    app: {
      appDataRequestStatus,
      appDataRequestError,
      authParams: { implements_check_password },
    },
    auth: { authorizationEnabled, authorized },
  } = state;

  return {
    appDataRequestStatus,
    appDataRequestError,
    authorizationRequired: implements_check_password && authorizationEnabled && !authorized,
  };
};

export default connect(mapStateToProps)(Dashboard);
