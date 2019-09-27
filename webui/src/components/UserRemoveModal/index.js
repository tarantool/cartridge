import React from 'react';
import { connect } from 'react-redux';
import { ConfirmModal } from '@tarantool.io/ui-kit';
import { hideRemoveUserModal, removeUser } from 'src/store/actions/users.actions';
import styled from 'react-emotion'

const Container = styled.div`
  padding: 0 16px;
  font-size: 14px;
  font-family: Open Sans;
  line-height: 22px;
`

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
        title="Please confirm"
        visible={removeUserModalVisible}
        onCancel={hideRemoveUserModal}
        onConfirm={this.handleOk}
        confirmText="Remove"
      >
        <Container>Removing user {username}</Container>
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
