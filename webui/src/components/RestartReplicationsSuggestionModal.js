// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
import { Alert, Button, Modal, Text, colors } from '@tarantool.io/ui-kit';

import {
  $restartReplicationsModal,
  detailsClose,
  restartReplicationsApplyClick,
} from 'src/store/effector/clusterSuggestions';

import type { Server } from '../generated/graphql-typing';
import type { State } from '../store/rootReducer';

const styles = {
  msg: css`
    margin-bottom: 20px;
    white-space: pre-line;
  `,
  list: css`
    list-style: none;
    padding-left: 0;
    color: ${colors.dark65};
  `,
  listItem: css`
    margin-bottom: 11px;

    &:last-child {
      margin-bottom: 0;
    }
  `,
};

const msg = `The replication isn't all right. Restart it, maybe it helps.`;
type Props = {
  serverList?: Server[],
};

const RestartReplicationsSuggestionModal = ({ serverList }: Props) => {
  const { visible, error, pending, suggestions } = useStore($restartReplicationsModal);

  if (!visible) return null;

  const richSuggestions =
    suggestions &&
    serverList &&
    suggestions.map(({ uuid }) => {
      const instance = serverList.find((instance) => instance.uuid === uuid);
      if (!instance) {
        return uuid;
      }

      return '' + instance.uri + (instance.alias ? ` (${instance.alias})` : '');
    });

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

const mapStateToProps = ({ clusterPage: { serverList } }: State) => {
  return { serverList };
};

export default connect(mapStateToProps)(RestartReplicationsSuggestionModal);
