/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './DisableServersSuggestionModal.styles';

const { $disableServersModal, detailsClose, disableServersApplyClick } = cluster.suggestions;
const { $serverList, selectors } = cluster.serverList;

const msg =
  'Some instances are malfunctioning and impede \
editing clusterwide configuration. Disable them temporarily \
if you want to operate topology.';

const DisableServersSuggestionModal = () => {
  const { visible, error, pending, suggestions } = useStore($disableServersModal);
  const serverListStore = useStore($serverList);

  const richSuggestions = useMemo(
    () =>
      (suggestions &&
        serverListStore &&
        suggestions
          .map(({ uuid }) => {
            const instance = selectors.serverGetByUuid(serverListStore, uuid);
            return instance ? '' + instance.uri + (instance.alias ? ` (${instance.alias})` : '') : '';
          })
          .filter(Boolean)) ||
      undefined,
    [suggestions, serverListStore]
  );

  if (!visible) return null;

  return (
    <Modal
      className="meta-test__DisableServersSuggestionModal"
      footerControls={[
        <Button
          key={0}
          intent="primary"
          size="l"
          text="Disable"
          onClick={disableServersApplyClick}
          loading={pending}
        />,
      ]}
      onClose={detailsClose}
      title="Disable instances"
    >
      <Text className={styles.msg} tag="p">
        {msg}
      </Text>
      <Text className={styles.list} tag="ul">
        {richSuggestions?.map((row) => (
          <li className={styles.listItem} key={row}>
            {row}
          </li>
        ))}
      </Text>
      {error && (
        <Alert type="error">
          <Text variant="basic">{error}</Text>
        </Alert>
      )}
    </Modal>
  );
};

export default DisableServersSuggestionModal;
