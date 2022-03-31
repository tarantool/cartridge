/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { ChangeEvent, FormEvent, useCallback } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, LabeledInput, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { $zoneAddModal, zoneAddModalCloseEvent, zoneAddModalSetValueEvent, zoneAddModalSubmitEvent } = cluster.zones;

const ZoneAddModal = () => {
  const { value, visible, pending, error } = useStore($zoneAddModal);

  const handleInputChange = useCallback((event: ChangeEvent<HTMLInputElement>) => {
    zoneAddModalSetValueEvent(event.target.value);
  }, []);

  const handleClose = useCallback(() => {
    zoneAddModalCloseEvent();
  }, []);

  const handleSubmit = useCallback((event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    zoneAddModalSubmitEvent();
  }, []);

  return (
    <Modal
      key={visible}
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
      onClose={handleClose}
      onSubmit={handleSubmit}
    >
      <LabeledInput
        label="Name of zone"
        name="zone_name"
        value={value}
        disabled={pending}
        onChange={handleInputChange}
        autoFocus
      />
      {error && (
        <Alert className="ZoneAddModal_error" type="error">
          <Text tag="span">{error}</Text>
        </Alert>
      )}
    </Modal>
  );
};

export default ZoneAddModal;
