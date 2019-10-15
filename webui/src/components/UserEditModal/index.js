import React from 'react';
import { connect } from 'react-redux';
import { hideEditUserModal } from 'src/store/actions/users.actions';
import { Modal } from '@tarantool.io/ui-kit';
import UserEditForm from './UserEditForm';

class UserEditModal extends React.Component {
  render() {
    const {
      editUserModalVisible,
      error,
      loading,
      hideEditUserModal,
      username
    } = this.props;

    return (
      <Modal
        className='meta-test__UserEditModal'
        title={`Edit ${username}`}
        visible={editUserModalVisible}
        width={550}
        onClose={hideEditUserModal}
      >
        <UserEditForm
          error={error}
          loading={loading}
          onClose={hideEditUserModal}
        />
      </Modal>
    );
  }
}

const mapStateToProps = ({
  ui: {
    editUserModalVisible,
    editUserId: username
  }
}) => ({
  editUserModalVisible,
  username
});

const mapDispatchToProps = {
  hideEditUserModal
};

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(UserEditModal);
