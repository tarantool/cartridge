/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import UnconfiguredInstancesList from './components/UnconfiguredInstancesList';
import UnconfiguredInstancesListHeader from './components/UnconfiguredInstancesListHeader';

const { $serverList, selectors } = cluster.serverList;

const UnconfiguredInstancesListPageSection = () => {
  const serverListStore = useStore($serverList);

  const unConfiguredServers = useMemo(() => selectors.unConfiguredServerList(serverListStore), [serverListStore]);

  if (unConfiguredServers.length < 1) {
    return null;
  }

  return (
    <PageSection title="Unconfigured Instances">
      <UnconfiguredInstancesListHeader count={unConfiguredServers.length} />
      <UnconfiguredInstancesList servers={unConfiguredServers} />
    </PageSection>
  );
};

export default UnconfiguredInstancesListPageSection;
