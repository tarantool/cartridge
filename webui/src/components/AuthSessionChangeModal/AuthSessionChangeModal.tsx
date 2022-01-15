/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Button, Modal } from '@tarantool.io/ui-kit';

import { app } from 'src/models';

import { styles } from './AuthSessionChangeModal.styles';

const { $authSessionChangeModalVisibility, changeAuthSessionEvent } = app;

export const AuthSessionChangeModal = () => {
  const authSessionChangeModalVisibility = useStore($authSessionChangeModalVisibility);

  const handleClose = useCallback(() => void changeAuthSessionEvent(), []);

  if (!authSessionChangeModalVisibility) {
    return null;
  }

  return (
    <Modal
      visible
      onClose={handleClose}
      footerControls={[
        <Button key="Reload" intent="primary" onClick={handleClose}>
          Reload
        </Button>,
      ]}
    >
      <div className={styles.root}>This tab session is stale. Page will be reloaded.</div>
    </Modal>
  );
};
