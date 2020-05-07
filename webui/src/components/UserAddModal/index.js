import React from 'react';
import { useStore } from 'effector-react';
import { Modal } from '@tarantool.io/ui-kit';
import usersStore from 'src/store/effector/users';
import { UserAddForm } from './UserAddForm';

const { $userAddModal, hideModal } = usersStore;

export const UserAddModal = () => {
  const { visible, error } = useStore($userAddModal);

  return (
    <Modal
      className='meta-test__UserAddForm'
      title="Add a new user"
      visible={visible}
      destroyOnClose={true}
      footer={null}
      onClose={hideModal}
    >
      <UserAddForm onClose={hideModal} error={error} />
    </Modal>
  );
};
