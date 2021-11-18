/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';

import { Maybe, ServerListReplicaset, cluster } from 'src/models';

import ReplicasetAddOrEditForm from './ReplicasetAddOrEditForm';
import { ReplicasetAddOrEditValues } from './ReplicasetAddOrEditForm.form';

const { $cluster, selectors, $knownRolesNames, $failoverParamsMode } = cluster.serverList;

export interface ReplicasetAddOrEditFormConnectorProps {
  replicaset?: Maybe<ServerListReplicaset>;
  pending: boolean;
  onClose: () => void;
  onSubmit: (values: ReplicasetAddOrEditValues) => void;
}

const ReplicasetAddOrEditFormConnector = ({
  replicaset,
  pending,
  onClose,
  onSubmit,
}: ReplicasetAddOrEditFormConnectorProps) => {
  const clusterStore = useStore($cluster);
  const knownRolesNames = useStore($knownRolesNames);
  const failoverParamsMode = useStore($failoverParamsMode);

  const [clusterSelfUri, knownRoles, vshardGroupsNames] = useMemo(
    () => [
      selectors.clusterSelfUri(clusterStore),
      selectors.knownRoles(clusterStore).reverse(),
      selectors.vshardGroupsNames(clusterStore),
    ],
    [clusterStore]
  );

  return (
    <ReplicasetAddOrEditForm
      onClose={onClose}
      onSubmit={onSubmit}
      pending={pending}
      replicaset={replicaset}
      clusterSelfUri={clusterSelfUri}
      knownRoles={knownRoles}
      knownRolesNames={knownRolesNames}
      vshardGroupsNames={vshardGroupsNames}
      failoverParamsMode={failoverParamsMode ?? undefined}
    />
  );
};

export default ReplicasetAddOrEditFormConnector;
