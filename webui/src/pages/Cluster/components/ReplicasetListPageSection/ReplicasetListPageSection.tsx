/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo, useState } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import ReplicasetFilterInput from 'src/components/ReplicasetFilterInput';
import * as models from 'src/models';

import PageSectionSubTitle from './components/PageSectionSubTitle';
import ReplicasetList from './components/ReplicasetList';

import { styles } from './ReplicasetListPageSection.styles';

const { $serverList, $cluster, selectors, filters } = models.cluster.serverList;

const ReplicasetListPageSection = () => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const [filter, setFilter] = useState('');

  const [{ configured }, { total, unhealthy }, issues, replicasetList, serverStat] = useMemo(
    () => [
      selectors.serverListCounts(serverListStore),
      selectors.replicasetCounts(serverListStore),
      selectors.issues(serverListStore),
      selectors.replicasetList(serverListStore),
      selectors.serverStat(serverListStore),
    ],
    [serverListStore]
  );

  const [knownRoles, cluster, clusterSelf, failoverParamsMode] = useMemo(
    () => [
      selectors.knownRoles(clusterStore),
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
    <PageSection
      title="Replica sets"
      subTitle={
        <PageSectionSubTitle
          configured={configured}
          total={total}
          unhealthy={unhealthy}
          filter={filter}
          length={filteredSearchableReplicasetList.length}
        />
      }
      topRightControls={[
        <ReplicasetFilterInput
          key={0}
          className={cx(styles.clusterFilter, 'meta-test__Filter')}
          value={filter}
          setValue={setFilter}
          roles={knownRoles}
        />,
      ]}
    >
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
        <div>No replicaset found</div>
      )}
    </PageSection>
  );
};

export default memo(ReplicasetListPageSection);
