// @flow
import React from 'react';
import { css } from 'emotion'
import { useStore } from 'effector-react';
import {
  Alert,
  Button,
  Modal,
  Text,
  colors
} from '@tarantool.io/ui-kit';
import {
  $advertiseModal,
  applyClick,
  detailsClose
} from 'src/store/effector/clusterSuggestions'

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
  `
};

const msg = 'One or more servers were restarted with a new advertise uri.\n\
Now they’re unreachable for RPC (i.e for vshard-routers) \
and replication isn\'t running.\
To make it operable again the clusterwide configuration should be updated:';

export const ClusterSuggestionsModal = () => {
  const {
    visible,
    error,
    pending,
    suggestions
  } = useStore($advertiseModal);

  if (!visible)
    return null;

  return (
    <Modal
      className={'meta-test__ClusterSuggestionsModal'}
      footerControls={[
        <Button intent='primary' size='l' text='Update' onClick={applyClick} loading={pending} />
      ]}
      onClose={detailsClose}
      title='Change advertise URI'
    >
      <Text className={styles.msg} tag='p'>{msg}</Text>
      <Text className={styles.list} tag='ul'>
        {suggestions && suggestions.map(({ uri_new, uuid, uri_old }) => (
          <li className={styles.listItem} key={uuid}>{`${uri_old} -> ${uri_new}`}</li>
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
