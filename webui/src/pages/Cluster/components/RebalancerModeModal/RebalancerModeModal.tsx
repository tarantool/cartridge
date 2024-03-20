/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useEvent, useStore } from 'effector-react';
// @ts-ignore
import { Button, FormField, Modal, Select } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const rebalancerModeOptions = [
  { value: 'off', label: 'Off' },
  { value: 'manual', label: 'Manual' },
  { value: 'auto', label: 'Auto' },
];

const RebalancerModeModal = () => {
  const { value, pending } = useStore(cluster.replicasetModeConfigure.$rebalancerModeConfigureModal);
  const rebalancerModeModalCloseEvent = useEvent(cluster.replicasetModeConfigure.rebalancerModeModalCloseEvent);
  const changeRebalancerModeEvent = useEvent(cluster.replicasetModeConfigure.changeRebalancerModeEvent);
  const saveRebalancerModeEvent = useEvent(cluster.replicasetModeConfigure.saveRebalancerModeEvent);

  if (value === null) {
    return null;
  }

  return (
    <Modal
      footerControls={[
        <Button
          key={0}
          className="meta-test__RebalancerModeModalSubmitBtn"
          type="button"
          intent="primary"
          text="Update"
          disabled={pending}
          size="l"
          onClick={saveRebalancerModeEvent}
        />,
      ]}
      visible
      title="Update rebalancer mode"
      onClose={rebalancerModeModalCloseEvent}
    >
      <FormField label="Rebalancer mode" largeMargins>
        <Select options={rebalancerModeOptions} value={value} onChange={changeRebalancerModeEvent} />
      </FormField>
    </Modal>
  );
};

export default RebalancerModeModal;
