import React, { useCallback } from 'react';
import { useStore } from 'effector-react';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Modal } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import ReplicasetAddOrEditForm from '../ReplicasetAddOrEditForm';
import SelectedReplicaset from '../SelectedReplicaset';

import { styles } from './ReplicasetConfigureModal.styles';

const { $replicasetConfigureModal, replicasetConfigureModalCloseEvent, editReplicasetEvent } =
  cluster.replicasetConfigure;

const ReplicasetConfigureModal = () => {
  const { visible, pending, replicaset } = useStore($replicasetConfigureModal);

  const handleClose = useCallback(() => {
    replicasetConfigureModalCloseEvent();
  }, []);

  const handleSubmit = useCallback(
    (values) => {
      if (replicaset) {
        editReplicasetEvent({
          uuid: replicaset.uuid,
          ...values,
        });
      }
    },
    [replicaset]
  );

  if (!visible) {
    return null;
  }

  return (
    <Modal
      visible={visible}
      className="meta-test__EditReplicasetModal"
      title="Edit replica set"
      onClose={handleClose}
      wide
    >
      <SelectedReplicaset className={styles.splash} replicaset={replicaset} />
      <ReplicasetAddOrEditForm
        replicaset={replicaset}
        onSubmit={handleSubmit}
        onClose={handleClose}
        pending={pending}
      />
    </Modal>
  );
};

export default ReplicasetConfigureModal;
