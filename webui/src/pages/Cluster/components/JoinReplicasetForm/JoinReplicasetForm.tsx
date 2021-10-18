/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
// @ts-ignore
import { Button, Modal } from '@tarantool.io/ui-kit';

import { JoinReplicasetFormikProps, withJoinReplicasetForm } from './JoinReplicasetForm.form';

import { styles } from './JoinReplicasetForm.styles';

const JoinReplicasetForm = ({ onClose, handleSubmit, handleReset }: JoinReplicasetFormikProps) => {
  return (
    <form onSubmit={handleSubmit} onReset={handleReset} noValidate>
      <div>JoinReplicasetForm</div>
      <Modal.Footer
        className={styles.splash}
        controls={[
          <Button key="Cancel" type="button" onClick={onClose} size="l">
            Cancel
          </Button>,
          <Button
            key="Join"
            className="meta-test__JoinReplicaSetBtn"
            intent="primary"
            type="submit"
            text="Join replica set"
            size="l"
          />,
        ]}
      />
    </form>
  );
};

export default withJoinReplicasetForm(JoinReplicasetForm);
