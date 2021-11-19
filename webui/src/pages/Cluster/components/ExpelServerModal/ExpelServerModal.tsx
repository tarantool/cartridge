/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { ConfirmModal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { $serverExpelModal, serverExpelEvent, serverExpelModalCloseEvent } = cluster.serverExpel;

const ExpelServerModal = () => {
  const { value, visible, pending } = useStore($serverExpelModal);

  const handleConfirm = useCallback(() => {
    serverExpelEvent();
  }, []);

  const handleCancel = useCallback(() => {
    serverExpelModalCloseEvent();
  }, []);

  return (
    <ConfirmModal
      className="meta-test__ExpelServerModal"
      title="Expel server"
      visible={visible}
      confirmText="Expel"
      confirmPreloader={pending}
      onConfirm={handleConfirm}
      onCancel={handleCancel}
    >
      <Text tag="p">Do you really want to expel the server {value?.alias ?? value?.uri ?? ''}?</Text>
    </ConfirmModal>
  );
};

export default ExpelServerModal;
