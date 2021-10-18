/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Spin } from '@tarantool.io/ui-kit';

import { PageLayout } from 'src/components/PageLayout';
import { cluster } from 'src/models';

import { ClusterControllers } from './ClusterControllers';
import { ClusterModals } from './ClusterModals';
import ButtonsPanel from './components/ButtonsPanel';
import ReplicasetListPageSection from './components/ReplicasetListPageSection';
import UnconfiguredServerListPageSection from './components/UnconfiguredServerListPageSection';

const { $isClusterPageReady } = cluster.page;

const CLUSTER_PAGE_TITLE = 'Cluster';

const Cluster = () => {
  const isReady = useStore($isClusterPageReady);

  return (
    <>
      <ClusterControllers />
      <ClusterModals />
      <PageLayout heading={CLUSTER_PAGE_TITLE} headingContent={isReady ? <ButtonsPanel /> : null}>
        <Spin enable={!isReady}>
          <UnconfiguredServerListPageSection />
          <ReplicasetListPageSection />
        </Spin>
      </PageLayout>
    </>
  );
};

export default Cluster;
