import React from 'react';

import AddLabelForServerModal from './components/ClusterAddLabelModal';
import ExpelServerModal from './components/ExpelServerModal';
import FailoverModal from './components/FailoverModal';
import ProbeServerModal from './components/ProbeServerModal';
import RebalancerModal from './components/RebalancerModal';
import RebalancerModeModal from './components/RebalancerModeModal';
import ReplicasetConfigureModal from './components/ReplicasetConfigureModal';
import ServerConfigureModal from './components/ServerConfigureModal';
import ServerDetailsModal from './components/ServerDetailsModal';
import ZoneAddModal from './components/ZoneAddModal';

export const ClusterModals = () => (
  <>
    <RebalancerModal />
    <RebalancerModeModal />
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
