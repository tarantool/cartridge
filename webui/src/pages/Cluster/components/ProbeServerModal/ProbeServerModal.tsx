import React, { useCallback } from 'react';
import { useStore } from 'effector-react';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Modal } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import ProbeServerModalForm from '../ProbeServerModalForm';

const { $serverProbeModal, serverProbeModalCloseEvent } = cluster.serverProbe;

const ProbeServerModal = () => {
  const { visible } = useStore($serverProbeModal);

  const handleClose = useCallback(() => {
    serverProbeModalCloseEvent();
  }, []);

  if (!visible) {
    return null;
  }

  return (
    <Modal className="ProbeServerModal" title="Probe server" onClose={handleClose} visible={visible}>
      <ProbeServerModalForm />
    </Modal>
  );
};

export default ProbeServerModal;
