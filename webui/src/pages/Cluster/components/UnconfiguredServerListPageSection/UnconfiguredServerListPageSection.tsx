/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import PageSectionSubTitle from './components/PageSectionSubTitle';
import UnconfiguredServerList from './components/UnconfiguredServerList';

const { $cluster, $serverList, selectors } = cluster.serverList;

const UnconfiguredServersPageSection = () => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const unConfiguredServers = useMemo(() => selectors.unConfiguredServerList(serverListStore), [serverListStore]);
  const clusterSelf = useMemo(() => selectors.clusterSelf(clusterStore), [clusterStore]);

  if (unConfiguredServers.length < 1) {
    return null;
  }

  return (
    <PageSection title="Unconfigured servers" subTitle={<PageSectionSubTitle count={unConfiguredServers.length} />}>
      <UnconfiguredServerList clusterSelf={clusterSelf} servers={unConfiguredServers} />
    </PageSection>
  );
};

export default UnconfiguredServersPageSection;
