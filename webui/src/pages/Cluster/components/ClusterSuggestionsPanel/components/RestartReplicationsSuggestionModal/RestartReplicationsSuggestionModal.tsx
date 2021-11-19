/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './RestartReplicationsSuggestionModal.styles';

const { $restartReplicationsModal, detailsClose, restartReplicationsApplyClick } = cluster.suggestions;
const { $serverList, selectors } = cluster.serverList;

const msg = `The replication isn't all right. Restart it, maybe it helps.`;

const RestartReplicationsSuggestionModal = () => {
  const { visible, error, pending, suggestions } = useStore($restartReplicationsModal);
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
      className="meta-test__RestartReplicationSuggestionModal"
      footerControls={[
        <Button
          key={0}
          intent="primary"
          size="l"
          text="Restart"
          onClick={restartReplicationsApplyClick}
          loading={pending}
        />,
      ]}
      onClose={detailsClose}
      title="Restart replication"
    >
      <Text className={styles.msg} tag="p">
        {msg}
      </Text>
      <Text className={styles.list} tag="ul">
        {richSuggestions &&
          richSuggestions.map((row) => (
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

export default RestartReplicationsSuggestionModal;
