import React from 'react';
import { connect } from 'react-redux';
import Modal from 'src/components/Modal';
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
      <Modal
        title="Please confirm"
        visible={removeUserModalVisible}
        width={350}
        onCancel={hideRemoveUserModal}
        onOk={this.handleOk}
        okText="Remove"
        destroyOnClose={true}
      >
        {`Removing user ${username}`}
      </Modal>
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
