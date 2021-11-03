import React from 'react';
import { SplashError } from '@tarantool.io/ui-kit';

import { getErrorMessage } from 'src/api';
import { isGraphqlAccessDeniedError, isGraphqlErrorResponse } from 'src/api/graphql';
import { isRestAccessDeniedError, isRestErrorResponse } from 'src/api/rest';
import Cluster from 'src/pages/Cluster';

// import Cluster from 'src/pages/ClusterLegacy';

class Dashboard extends React.Component {
  render() {
    const { appDataRequestStatus, appDataRequestError, authorizationRequired, location, history } = this.props;
    const isLoading = !appDataRequestStatus.loaded;

    if (isLoading || authorizationRequired) {
      return null;
    }

    return appDataRequestError ? this.renderError(appDataRequestError) : this.renderApp(location, history);
  }

  renderApp(location, history) {
    return <Cluster location={location} history={history} />;
  }

  renderError(error) {
    // TODO: consider whether it is really important to distinguish "access denied" errors from others
    const title = isNotAccessError(error) ? 'Request failed' : 'Sorry, something went wrong';
    const description = getErrorMessage(error);

    return <SplashError title={title} description={description} />;
  }
}

const isNotAccessError = (error) => {
  return (
    (isRestErrorResponse(error) && !isRestAccessDeniedError(error)) ||
    (isGraphqlErrorResponse(error) && !isGraphqlAccessDeniedError(error))
  );
};

export default Dashboard;
