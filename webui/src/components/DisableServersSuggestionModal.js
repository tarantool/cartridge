// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
import { Alert, Button, Modal, Text, colors } from '@tarantool.io/ui-kit';

import type { Server } from 'src/generated/graphql-typing';
import { $disableServersModal, detailsClose, disableServersApplyClick } from 'src/store/effector/clusterSuggestions';
import type { State } from 'src/store/rootReducer';

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

const msg =
  'Some instances are malfunctioning and impede \
editing clusterwide configuration. Disable them temporarily \
if you want to operate topology.';

type Props = {
  serverList?: Server[],
};

const DisableServersSuggestionModal = ({ serverList }: Props) => {
  const { visible, error, pending, suggestions } = useStore($disableServersModal);

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

export default connect(mapStateToProps)(DisableServersSuggestionModal);
