/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
// @ts-ignore
import { FlatList } from '@tarantool.io/ui-kit';

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
          totalBucketsCount: cluster?.vshard_bucket_count ?? undefined,
        },
      };
    });
  }, [replicaset, cluster, clusterSelf, serverStat]);

  if (!servers || servers.length === 0) {
    return null;
  }

  return (
    <FlatList className="meta-test__ReplicasetServerList">
      {servers.map(({ server, additional }) => (
        <ReplicasetServerListItem
          key={server.uuid}
          server={server}
          additional={additional}
          showFailoverPromote={servers && servers.length > 1 && failoverParamsMode === 'stateful'}
        />
      ))}
    </FlatList>
  );
};

export default memo(ReplicasetServerList);
