import React, { useMemo } from 'react';
import { RouteComponentProps, withRouter } from 'react-router-dom';

import { getSearchParams } from 'src/misc/url';
import { cluster } from 'src/models';

const { ClusterReplicasetConfigureGate } = cluster.replicasetConfigure;

export type ReplicasetConfigureModalControllerProps = Pick<RouteComponentProps, 'location'>;

const ReplicasetConfigureModalController = ({ location }: ReplicasetConfigureModalControllerProps) => {
  const uuid = useMemo((): string | undefined => getSearchParams(location.search)?.r, [location.search]);
  return uuid ? <ClusterReplicasetConfigureGate uuid={uuid} /> : null;
};

export default withRouter(ReplicasetConfigureModalController);
