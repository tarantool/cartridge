import React from 'react';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
import { Alert, ConfirmModal, Text } from '@tarantool.io/ui-kit';

import { $userRemoveModal, hideModal, removeUserFx } from 'src/store/effector/users';

const styles = {
  error: css`
    min-height: 24px;
    margin: 16px 0 24px;
  `,
};

export const UserRemoveModal = () => {
  const { error, username, visible } = useStore($userRemoveModal);
  const pending = useStore(removeUserFx.pending);

  return (
    <ConfirmModal
      className="meta-test__UserRemoveModal"
      title="Please confirm"
      visible={visible}
      onCancel={hideModal}
      onConfirm={() => removeUserFx(username)}
      confirmText="Remove"
      confirmPreloader={pending}
    >
      <Text>
        Removing user {username}
        {error ? (
          <Alert type="error" className={styles.error}>
            <Text variant="basic">{error}</Text>
          </Alert>
        ) : null}
      </Text>
    </ConfirmModal>
  );
};
