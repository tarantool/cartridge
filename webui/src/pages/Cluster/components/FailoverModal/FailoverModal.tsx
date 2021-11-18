/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useStore } from 'effector-react';

import { cluster } from 'src/models';

import FailoverModalForm from './components/FailoverModalForm';

const { $failoverModal, $failover } = cluster.failover;
const { $failoverParamsMode } = cluster.serverList;

const FailoverModal = () => {
  const { visible } = useStore($failoverModal);
  const failover = useStore($failover);
  const mode = useStore($failoverParamsMode);

  return visible ? <FailoverModalForm mode={mode ?? undefined} failover={failover} /> : null;
};

export default FailoverModal;
