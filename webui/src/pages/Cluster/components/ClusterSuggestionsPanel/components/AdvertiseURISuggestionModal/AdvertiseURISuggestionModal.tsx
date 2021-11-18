/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './AdvertiseURISuggestionModal.styles';

const { $advertiseURIModal, advertiseURIApplyClick, detailsClose } = cluster.suggestions;

const msg =
  "One or more servers were restarted with a new advertise uri.\n\
Now they’re unreachable for RPC (i.e for vshard-routers) \
and replication isn't running.\
To make it operable again the clusterwide configuration should be updated:";

const AdvertiseURISuggestionModal = () => {
  const { visible, error, pending, suggestions } = useStore($advertiseURIModal);

  if (!visible) return null;

  return (
    <Modal
      className="meta-test__AdvertiseURISuggestionModal"
      footerControls={[
        <Button
          key="Update"
          intent="primary"
          size="l"
          text="Update"
          onClick={advertiseURIApplyClick}
          loading={pending}
        />,
      ]}
      onClose={detailsClose}
      title="Change advertise URI"
    >
      <Text className={styles.msg} tag="p">
        {msg}
      </Text>
      <Text className={styles.list} tag="ul">
        {suggestions &&
          suggestions.map(({ uri_new, uuid, uri_old }) => (
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

export default AdvertiseURISuggestionModal;
