// @flow
import React from 'react';
import { useStore } from 'effector-react';
import { Alert, Button, LabeledInput, Modal, Text } from '@tarantool.io/ui-kit';

import { zoneAddModalClose } from 'src/store/effector/clusterZones';
import { $zoneAddModal, addServerZone, zoneInputChange } from 'src/store/effector/clusterZones/zoneAddModal';

const handleInputChange = ({ target }: InputEvent) => {
  if (target instanceof HTMLInputElement) {
    zoneInputChange(target.value || '');
  }
};

const handleSubmit = (evt: Event) => {
  evt.preventDefault();
  addServerZone();
};

export const ZoneAddModal = () => {
  const { pending, value, visible, error } = useStore($zoneAddModal);

  return (
    <Modal
      className="ZoneAddModal"
      footerControls={[
        <Button
          key={0}
          className="meta-test__ZoneAddSubmitBtn"
          type="submit"
          intent="primary"
          text="Create zone"
          size="l"
          loading={pending}
        />,
      ]}
      visible={visible}
      title="Add name of zone"
      onClose={zoneAddModalClose}
      onSubmit={handleSubmit}
    >
      <LabeledInput label="Name of zone" name="zone_name" value={value} onChange={handleInputChange} autoFocus />
      {error && (
        <Alert className={'ZoneAddModal_error'} type="error">
          <Text tag="span">{error}</Text>
        </Alert>
      )}
    </Modal>
  );
};
