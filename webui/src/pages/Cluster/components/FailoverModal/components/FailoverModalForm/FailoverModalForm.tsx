/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback } from 'react';
// @ts-ignore
import { Modal } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import FailoverModalFormForm, { FailoverFormProps } from './FailoverModalForm.form';

const { failoverModalCloseEvent } = cluster.failover;

const FailoverModalForm = ({ mode, failover }: FailoverFormProps) => {
  const handleClose = useCallback(() => failoverModalCloseEvent(), []);

  return (
    <Modal visible className="meta-test__FailoverModal" title="Failover control" onClose={handleClose}>
      <FailoverModalFormForm mode={mode} failover={failover} />
    </Modal>
  );
};

export default FailoverModalForm;
