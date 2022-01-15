/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { PageSection } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import UnconfiguredServerList from './components/UnconfiguredServerList';

const { $serverList, selectors } = cluster.serverList;

const UnconfiguredServersPageSection = () => {
  const serverListStore = useStore($serverList);

  const unConfiguredServers = useMemo(() => selectors.unConfiguredServerList(serverListStore), [serverListStore]);

  if (unConfiguredServers.length < 1) {
    return null;
  }

  return (
    <PageSection title="Unconfigured Servers" titleCounter={unConfiguredServers.length}>
      <UnconfiguredServerList servers={unConfiguredServers} />
    </PageSection>
  );
};

export default UnconfiguredServersPageSection;
