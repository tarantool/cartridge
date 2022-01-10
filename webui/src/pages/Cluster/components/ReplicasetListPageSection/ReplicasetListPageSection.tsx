/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useEffect, useMemo, useState } from 'react';
import { useStore } from 'effector-react';
import { useCore } from '@tarantool.io/frontend-core';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import * as models from 'src/models';

import ReplicasetList from './components/ReplicasetList';
import ReplicasetListHeader from './components/ReplicasetListHeader';

import { styles } from './ReplicasetListPageSection.styles';

const { $serverList, $cluster, selectors, filters } = models.cluster.serverList;

const ReplicasetListPageSection = () => {
  const core = useCore();
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const [filter, setFilter] = useState(core?.ss.get('cluster_filter') || '');

  useEffect(() => {
    core?.ss.set('cluster_filter', filter);
  }, [core, filter]);

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

  const replicasetListSearchable = useMemo(() => selectors.replicasetListSearchable(replicasetList), [replicasetList]);

  const filteredSearchableReplicasetList = useMemo(
    () => filters.filterSearchableReplicasetList(replicasetListSearchable, filter),
    [replicasetListSearchable, filter]
  );

  if (replicasetList.length < 1 || !cluster || !clusterSelf) {
    return null;
  }

  return (
    <PageSection title="Replicasets">
      <ReplicasetListHeader filter={filter} onFilterChange={setFilter} />
      {filteredSearchableReplicasetList.length ? (
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
