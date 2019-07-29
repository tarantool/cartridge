import React from 'react';
import { Table } from 'antd';
import { connect } from 'react-redux';
import { css } from 'emotion';
import UserActionsBtn from './UserActionsBtn';
import {
  getUsersList,
  resetUserState,
  showEditUserModal,
  showRemoveUserModal
} from 'src/store/actions/users.actions';

const styles = {
  clickableRow: css`
    cursor: pointer;
  `
};

class UsersTable extends React.Component {
  columns = [
    {
      title: 'Username',
      dataIndex: 'username',
      key: 'username'
    },
    {
      title: 'Full name',
      dataIndex: 'fullname',
      key: 'fullname'
    },
    {
      title: 'E-mail',
      dataIndex: 'email',
      key: 'email'
    }
  ];

  columnsWithActions = [
    ...this.columns,
    {
      key: 'action',
      title: 'Actions',
      render: ({ username }) => (
        <UserActionsBtn
          allowEditing={this.props.implements_edit_user}
          allowRemoving={this.props.implements_remove_user}
          username={username}
          onEditUser={this.props.showEditUserModal}
          onRemoveUser={this.props.showRemoveUserModal}
        />
      ),
      align: 'right',
      width: '100px'
    }
  ]

  componentDidMount() {
    this.props.getUsersList();
  }

  componentWillUnmount() {
    this.props.resetUserState();
  }

  handleRow = item => ({
    onClick: () => this.props.implements_edit_user && this.props.showEditUserModal(item.username)
  });

  render() {
    const {
      fetchingUserList,
      items,
      implements_edit_user,
      implements_remove_user
    } = this.props;

    return (
      <Table
        columns={implements_edit_user || implements_remove_user ? this.columnsWithActions : this.columns}
        dataSource={items}
        pagination={false}
        rowKey='username'
        rowClassName={() => implements_edit_user ? styles.clickableRow : ''}
        onRow={this.handleRow}
        loading={fetchingUserList}
      />
    );
  }
}

const mapStateToProps = ({
  app: {
    authParams: {
      implements_remove_user,
      implements_edit_user
    }
  },
  users: {
    items
  },
  ui: {
    fetchingUserList
  }
}) => ({
  fetchingUserList,
  items,
  implements_remove_user,
  implements_edit_user
});

const mapDispatchToProps = {
  getUsersList,
  resetUserState,
  showEditUserModal,
  showRemoveUserModal
};

export default connect(mapStateToProps, mapDispatchToProps)(UsersTable);
