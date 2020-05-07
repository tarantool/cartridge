import React from 'react';
import { useStore } from 'effector-react';
import { Modal } from '@tarantool.io/ui-kit';
import usersStore from 'src/store/effector/users';
import { UserEditForm } from './UserEditForm';

const { $userEditModal, hideModal } = usersStore;

export const UserEditModal =({
  error,
  loading
}) => {
  const { visible, username } = useStore($userEditModal);

  return (
    <Modal
      className='meta-test__UserEditModal'
      title={`Edit ${username}`}
      visible={visible}
      onClose={hideModal}
    >
      <UserEditForm
        error={error}
        loading={loading}
        onClose={hideModal}
      />
    </Modal>
  );
};
