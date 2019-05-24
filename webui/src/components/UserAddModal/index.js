import React from 'react';
import { connect } from 'react-redux';
import { hideAddUserModal } from 'src/store/actions/users.actions';
import Modal from 'src/components/Modal';
import UserAddForm from './UserAddForm';

class UserAddModal extends React.Component {
  render() {
    const {
      addUser,
      addUserModalVisible,
      error,
      loading,
      hideAddUserModal,
    } = this.props;

    return (
      <Modal
        title="Add a new user"
        visible={addUserModalVisible}
        width={550}
        onCancel={hideAddUserModal}
        destroyOnClose={true}
        footer={null}
      >
        <UserAddForm
          addUser={addUser}
          error={error}
          loading={loading}
        />
      </Modal>
    );
  }
}

const mapStateToProps = ({
  ui: {
    addUserModalVisible
  }
}) => ({
  addUserModalVisible
});

const mapDispatchToProps = {
  hideAddUserModal
};

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(UserAddModal);
