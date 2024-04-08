/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useEvent, useStore } from 'effector-react';
// @ts-ignore
import { Button, FormField, Modal, Select } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const rebalancerOptions = [
  { value: 'unset', label: 'Unset' },
  { value: 'true', label: 'True' },
  { value: 'false', label: 'False' },
];

const RebalancerModal = () => {
  const { value, pending } = useStore(cluster.rebalancerConfigure.$rebalancerConfigureModal);
  const rebalancerModalCloseEvent = useEvent(cluster.rebalancerConfigure.rebalancerModalCloseEvent);
  const changeRebalancerEvent = useEvent(cluster.rebalancerConfigure.changeRebalancerEvent);
  const saveRebalancerEvent = useEvent(cluster.rebalancerConfigure.saveRebalancerEvent);

  if (value === null) {
    return null;
  }

  return (
    <Modal
      footerControls={[
        <Button
          key={0}
          className="meta-test__RebalancerModalSubmitBtn"
          type="button"
          intent="primary"
          text="Update"
          disabled={pending}
          size="l"
          onClick={saveRebalancerEvent}
        />,
      ]}
      visible
      title="Update rebalancer"
      onClose={rebalancerModalCloseEvent}
    >
      <FormField label="Rebalancer" largeMargins>
        <Select options={rebalancerOptions} value={value} onChange={changeRebalancerEvent} />
      </FormField>
    </Modal>
  );
};

export default RebalancerModal;
