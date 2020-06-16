import React from 'react';
import { connect } from 'react-redux';
import { ConfirmModal, Text } from '@tarantool.io/ui-kit';
import { hideRemoveUserModal, removeUser } from 'src/store/actions/users.actions';

class UserRemoveModal extends React.Component {
  handleOk = () => this.props.removeUser(this.props.username);

  render() {
    const {
      hideRemoveUserModal,
      removeUserModalVisible,
      username
    } = this.props;

    return (
      <ConfirmModal
        className='meta-test__UserRemoveModal'
        title='Please confirm'
        visible={removeUserModalVisible}
        onCancel={hideRemoveUserModal}
        onConfirm={this.handleOk}
        confirmText='Remove'
      >
        <Text>Removing user {username}</Text>
      </ConfirmModal>
    );
  }
}

const mapStateToProps = ({
  ui: {
    removeUserModalVisible,
    removeUserId: username
  }
}) => ({
  removeUserModalVisible,
  username
});

const mapDispatchToProps = {
  hideRemoveUserModal,
  removeUser
};

export default connect(mapStateToProps, mapDispatchToProps)(UserRemoveModal);
