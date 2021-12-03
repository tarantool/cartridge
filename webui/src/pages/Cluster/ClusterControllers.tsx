import React from 'react';
import { core } from '@tarantool.io/frontend-core';

import { cluster } from 'src/models';

import ReplicasetConfigureModalController from './components/ReplicasetConfigureModalController';
import ServerConfigureModalController from './components/ServerConfigureModalController';
import ServerDetailsModalController from './components/ServerDetailsModalController';

const { AppTitle } = core.components;
const { page } = cluster;
const { ClusterPageGate } = page;

export const ClusterControllers = ({ title }: { title: string }) => (
  <>
    {AppTitle ? <AppTitle title={title} /> : null}
    <ClusterPageGate />
    <ServerDetailsModalController />
    <ServerConfigureModalController />
    <ReplicasetConfigureModalController />
  </>
);
