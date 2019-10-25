import React from 'react';
import { connect } from 'react-redux';
import { hideAddUserModal } from 'src/store/actions/users.actions';
import { Modal } from '@tarantool.io/ui-kit';
import UserAddForm from './UserAddForm';

class UserAddModal extends React.Component {
  render() {
    const {
      addUserModalVisible,
      hideAddUserModal
    } = this.props;

    return (
      <Modal
        className='meta-test__UserAddForm'
        title="Add a new user"
        visible={addUserModalVisible}
        onCancel={hideAddUserModal}
        destroyOnClose={true}
        footer={null}
        onClose={hideAddUserModal}
      >
        <UserAddForm onClose={hideAddUserModal} />
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
