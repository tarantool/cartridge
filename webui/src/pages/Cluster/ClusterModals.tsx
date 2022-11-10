import React from 'react';

import AddLabelForServerModal from 'src/pages/Cluster/components/ClusterAddLabelModal/AddLabelForServerModal';

import ExpelServerModal from './components/ExpelServerModal';
import FailoverModal from './components/FailoverModal';
import ProbeServerModal from './components/ProbeServerModal';
import ReplicasetConfigureModal from './components/ReplicasetConfigureModal';
import ServerConfigureModal from './components/ServerConfigureModal';
import ServerDetailsModal from './components/ServerDetailsModal';
import ZoneAddModal from './components/ZoneAddModal';

export const ClusterModals = () => (
  <>
    <ServerDetailsModal />
    <ServerConfigureModal />
    <ReplicasetConfigureModal />
    <ZoneAddModal />
    <ExpelServerModal />
    <ProbeServerModal />
    <FailoverModal />
    <AddLabelForServerModal />
  </>
);
