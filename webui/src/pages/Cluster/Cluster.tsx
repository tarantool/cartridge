/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Spin } from '@tarantool.io/ui-kit';

import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import { PageLayout } from 'src/components/PageLayout';
import { cluster } from 'src/models';

import { ClusterControllers } from './ClusterControllers';
import { ClusterModals } from './ClusterModals';
import { ClusterPanels } from './ClusterPanels';
import ButtonsPanel from './components/ButtonsPanel';
import ReplicasetListPageSection from './components/ReplicasetListPageSection';
import UnconfiguredServerListPageSection from './components/UnconfiguredServerListPageSection';

const { $clusterPage } = cluster.page;

const CLUSTER_PAGE_TITLE = 'Cluster';

const Cluster = () => {
  const { ready, error } = useStore($clusterPage);

  if (error && !ready) {
    return <PageDataErrorMessage error={error} />;
  }

  if (!ready) {
    <PageLayout heading={CLUSTER_PAGE_TITLE}>
      <Spin enable />
    </PageLayout>;
  }

  return (
    <>
      <ClusterControllers title={CLUSTER_PAGE_TITLE} />
      <ClusterModals />
      <PageLayout heading={CLUSTER_PAGE_TITLE} headingContent={<ButtonsPanel />}>
        <ClusterPanels />
        <UnconfiguredServerListPageSection />
        <ReplicasetListPageSection />
      </PageLayout>
    </>
  );
};

export default Cluster;
