import React from 'react';

import { cluster } from 'src/models';

import ReplicasetConfigureModalController from './components/ReplicasetConfigureModalController';
import ServerConfigureModalController from './components/ServerConfigureModalController';
import ServerDetailsModalController from './components/ServerDetailsModalController';

const { AppTitle } = window['tarantool_enterprise_core']?.components ?? {};
const { page } = cluster;
const { ClusterPageGate } = page;

const CLUSTER_PAGE_TITLE = 'Cluster';

export const ClusterControllers = () => (
  <>
    {AppTitle ? <AppTitle title={CLUSTER_PAGE_TITLE} /> : null}
    <ClusterPageGate />
    <ServerDetailsModalController />
    <ServerConfigureModalController />
    <ReplicasetConfigureModalController />
  </>
);
