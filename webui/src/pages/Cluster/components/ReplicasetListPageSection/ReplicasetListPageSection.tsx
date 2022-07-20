/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import * as models from 'src/models';

import ReplicasetList from './components/ReplicasetList';
import ReplicasetListHeader from './components/ReplicasetListHeader';

import { styles } from './ReplicasetListPageSection.styles';

const { $serverList, $cluster, $filteredReplicasetList, selectors } = models.cluster.serverList;

const ReplicasetListPageSection = () => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const filteredSearchableReplicasetList = useStore($filteredReplicasetList);

  const [issues, replicasetList, serverStat] = useMemo(
    () => [
      selectors.issues(serverListStore),
      selectors.replicasetList(serverListStore),
      selectors.serverStat(serverListStore),
    ],
    [serverListStore]
  );

  const [cluster, clusterSelf, failoverParamsMode] = useMemo(
    () => [
      selectors.cluster(clusterStore),
      selectors.clusterSelf(clusterStore),
      selectors.failoverParamsMode(clusterStore),
    ],
    [clusterStore]
  );

  if (replicasetList.length < 1 || !cluster || !clusterSelf) {
    return null;
  }

  return (
    <PageSection title="Replicasets">
      <ReplicasetListHeader />
      {filteredSearchableReplicasetList?.length ? (
        <ReplicasetList
          cluster={cluster}
          clusterSelf={clusterSelf}
          replicasetList={filteredSearchableReplicasetList}
          serverStat={serverStat}
          issues={issues}
          failoverParamsMode={failoverParamsMode}
        />
      ) : (
        <div className={styles.notFound}>No replicaset found</div>
      )}
    </PageSection>
  );
};

export default ReplicasetListPageSection;
