/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';

import { cluster } from 'src/models';
import type { GetClusterCluster, GetClusterClusterSelf, ServerListReplicaset, ServerListServerStat } from 'src/models';

import ReplicasetServerListItem, { ReplicasetServerListItemProps } from '../ReplicasetServerListItem';

const { selectors } = cluster.serverList;

export interface ReplicasetServerListProps {
  cluster: GetClusterCluster;
  clusterSelf: GetClusterClusterSelf;
  replicaset: ServerListReplicaset;
  serverStat: ServerListServerStat[];
  failoverParamsMode?: string;
  className?: string;
}

const ReplicasetServerList = (props: ReplicasetServerListProps) => {
  const { cluster, clusterSelf, replicaset, serverStat, failoverParamsMode } = props;

  const servers = useMemo(() => {
    const vshardGroupBucketsCount = selectors
      .clusterVshardGroups(cluster)
      .find(({ name }) => name === replicaset.vshard_group)?.bucket_count;

    return replicaset.servers.map((server): Pick<ReplicasetServerListItemProps, 'server' | 'additional'> => {
      const stat = serverStat.find(({ uuid }) => server.uuid === uuid);
      return {
        server,
        additional: {
          master: server.uuid === replicaset.master.uuid,
          activeMaster: server.uuid === replicaset.active_master.uuid,
          replicasetUUID: replicaset.uuid,
          selfURI: clusterSelf?.uri ?? undefined,
          ro: selectors.replicasetServerRo(server),
          statistics: stat?.statistics,
          vshardGroupBucketsCount,
        },
      };
    });
  }, [replicaset, cluster, clusterSelf, serverStat]);

  if (!servers || servers.length === 0) {
    return null;
  }

  return (
    <div className="meta-test__ReplicasetServerList" data-component="ReplicasetServerList">
      {servers.map(({ server, additional }) => (
        <ReplicasetServerListItem
          key={server.uuid}
          server={server}
          additional={additional}
          showFailoverPromote={
            servers && servers.length > 1 && (failoverParamsMode === 'stateful' || failoverParamsMode === 'raft')
          }
        />
      ))}
    </div>
  );
};

export default memo(ReplicasetServerList);
