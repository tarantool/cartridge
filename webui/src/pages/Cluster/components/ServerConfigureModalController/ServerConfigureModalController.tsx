import React, { useMemo } from 'react';
import { RouteComponentProps, withRouter } from 'react-router-dom';

import { getSearchParams } from 'src/misc/url';
import { cluster } from 'src/models';

const { ClusterServerConfigureGate } = cluster.serverConfigure;

export type ServerConfigureModalControllerProps = Pick<RouteComponentProps, 'location'>;

const ServerConfigureModalController = ({ location }: ServerConfigureModalControllerProps) => {
  const uri = useMemo((): string | undefined => getSearchParams(location.search)?.s, [location.search]);
  return uri ? <ClusterServerConfigureGate uri={uri} /> : null;
};

export default withRouter(ServerConfigureModalController);
