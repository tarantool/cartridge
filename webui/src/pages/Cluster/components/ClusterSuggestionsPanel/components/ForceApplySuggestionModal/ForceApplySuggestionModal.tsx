/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, Checkbox, FormField, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './ForceApplySuggestionModal.styles';

const {
  $forceApplyModal,
  detailsClose,
  forceApplyConfApplyClick,
  forceApplyInstanceCheck,
  forceApplyReasonCheck,
  forceApplyReasonUncheck,
} = cluster.suggestions;
const { $serverList, selectors } = cluster.serverList;

const fieldLabels = {
  operation_error: 'Operation error',
  config_error: 'Configuration error',
};

const msg = 'Some instances are misconfigured. \
You can heal it by reapplying configuration forcefully.';

const ForceApplySuggestionModal = () => {
  const { checked, visible, error, pending, suggestions } = useStore($forceApplyModal);
  const serverListStore = useStore($serverList);

  const serversLabels = useMemo(
    () =>
      selectors.serverList(serverListStore).reduce((acc, { uuid, alias, uri }) => {
        acc[uuid] = '' + uri + (alias ? ` (${alias})` : '');
        return acc;
      }, {}),
    [serverListStore]
  );

  if (!visible) return null;

  return (
    <Modal
      className="meta-test__ForceApplySuggestionModal"
      footerControls={[
        <Button
          key="Apply"
          intent="primary"
          size="l"
          text="Force apply"
          onClick={forceApplyConfApplyClick}
          loading={pending}
        />,
      ]}
      onClose={detailsClose}
      title="Force apply configuration"
    >
      <Text className={styles.msg} tag="p">
        {msg}
      </Text>
      {suggestions.map(([reason, uuids]) => {
        const deselectAll = uuids.map((uuid) => checked[uuid]).every(Boolean);

        return uuids.length ? (
          <FormField
            className="meta-test__errorField"
            label={fieldLabels[reason]}
            key={reason}
            subTitle={
              <Button
                intent="plain"
                onClick={() => (deselectAll ? forceApplyReasonUncheck(reason) : forceApplyReasonCheck(reason))}
                size="xs"
                text={deselectAll ? 'Deselect all' : 'Select all'}
              />
            }
          >
            {uuids.map((uuid) => (
              <Checkbox key={uuid} checked={checked[uuid]} onChange={() => forceApplyInstanceCheck(uuid)}>
                {serversLabels[uuid]}
              </Checkbox>
            ))}
          </FormField>
        ) : null;
      })}
      {error && (
        <Alert type="error">
          <Text variant="basic">{error}</Text>
        </Alert>
      )}
    </Modal>
  );
};

export default ForceApplySuggestionModal;
