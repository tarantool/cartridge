/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback, useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Modal, Tabbed } from '@tarantool.io/ui-kit';

import SelectedServersList from 'src/components/SelectedServersList';
import { app, cluster } from 'src/models';

import JoinReplicasetForm, { JoinReplicasetValues } from '../JoinReplicasetForm';
import ReplicasetAddOrEditForm, { ReplicasetAddOrEditValues } from '../ReplicasetAddOrEditForm';

import { styles } from './ServerConfigureModal.styles';

const { compact } = app.utils;
const { $cluster, selectors, $serverList } = cluster.serverList;

const { $serverConfigureModal, serverConfigureModalClosedEvent, joinReplicasetEvent, createReplicasetEvent } =
  cluster.serverConfigure;

const ServerConfigureModal = () => {
  const clusterStore = useStore($cluster);
  const serverListStore = useStore($serverList);
  const { visible, pending, uri, loading } = useStore($serverConfigureModal);

  const replicasetList = useMemo(() => selectors.replicasetList(serverListStore), [serverListStore]);
  const clusterSelfUri = useMemo(() => selectors.clusterSelfUri(clusterStore), [clusterStore]);
  const server = useMemo(() => selectors.serverGetByUri(serverListStore, uri), [uri, serverListStore]);

  const handleClose = useCallback(() => {
    serverConfigureModalClosedEvent();
  }, []);

  const handleCreateSubmit = useCallback(
    (values: ReplicasetAddOrEditValues) => {
      if (uri) {
        createReplicasetEvent({
          ...values,
          join_servers: [{ uri }],
        });
      }
    },
    [uri]
  );

  const handleJoinSubmit = useCallback(
    ({ replicasetUuid }: JoinReplicasetValues) => {
      if (uri && replicasetUuid) {
        joinReplicasetEvent({
          uri,
          uuid: replicasetUuid,
        });
      }
    },
    [uri]
  );

  const serverNode = useMemo(
    () =>
      server ? <SelectedServersList className={styles.splash} serverList={[server]} selfURI={clusterSelfUri} /> : null,
    [server, clusterSelfUri]
  );

  const tabs = useMemo(
    () =>
      compact([
        {
          label: 'Create Replica Set',
          content: (
            <div className={styles.tabContent}>
              {serverNode}
              <ReplicasetAddOrEditForm onSubmit={handleCreateSubmit} onClose={handleClose} pending={pending} />
            </div>
          ),
        },
        replicasetList.length > 0 && {
          label: 'Join Replica Set',
          content: (
            <div className={styles.tabContent}>
              {serverNode}
              <JoinReplicasetForm onSubmit={handleJoinSubmit} onClose={handleClose} pending={pending} />
            </div>
          ),
        },
      ]),
    [handleCreateSubmit, handleJoinSubmit, handleClose, pending, serverNode, replicasetList.length]
  );

  if (!visible) {
    return null;
  }

  return (
    <Modal
      visible={visible}
      className="meta-test__ConfigureServerModal"
      title="Configure server"
      onClose={handleClose}
      loading={loading}
      wide
    >
      <Tabbed tabs={tabs} />
    </Modal>
  );
};

export default ServerConfigureModal;
