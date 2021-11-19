import React from 'react';
import { Route, Switch } from 'react-router-dom';

import { cluster } from 'src/models';

const { ClusterServerDetailsGate } = cluster.serverDetails;

const ServerDetailsModalController = () => (
  <Switch>
    <Route
      path={cluster.page.paths.serverDetails({ uuid: ':instanceUUID' })}
      render={({
        match: {
          params: { instanceUUID },
        },
      }) => (instanceUUID ? <ClusterServerDetailsGate uuid={instanceUUID} /> : null)}
    />
  </Switch>
);

export default ServerDetailsModalController;
