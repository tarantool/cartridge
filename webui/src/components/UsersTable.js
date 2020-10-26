// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { memoizeWith, identity } from 'ramda';
import {
  Button,
  ControlsPanel,
  IconEdit,
  IconBucket,
  Table,
  Link,
  colors
} from '@tarantool.io/ui-kit';
import {
  getUsersList,
  resetUserState,
  showEditUserModal,
  showRemoveUserModal
} from 'src/store/actions/users.actions';
import { BUILT_IN_USERS } from 'src/constants';

const styles = {
  table: css`
    tr td:last-child {
      width: 1%;
      white-space: nowrap;
    }
  `,
  username: css`
    color: ${colors.dark};
    font-weight: 600;
  `
};

const tableColumns = memoizeWith(
  identity,
  (
    allowEdit,
    allowDelete,
    showEditUserModal,
    showRemoveUserModal
  ) => ([
    {
      Header: 'Username',
      accessor: 'username',
      Cell: ({ cell: { value } }) => (
        <Link
          href='#'
          className={styles.username}
          onClick={e => { e.preventDefault(); showEditUserModal(value); }}
        >
          {value}
        </Link>
      )
    },
    {
      Header: 'Full name',
      accessor: 'fullname',
      Cell: ({ cell: { value } }) => value || '—'
    },
    {
      Header: 'E-mail',
      accessor: 'email',
      Cell: ({ cell: { value } }) => value || '—'
    },
    {
      Header: 'Actions',
      disableSortBy: true,
      Cell: ({ row: { values } }) => {
        return (
          <ControlsPanel
            thin
            controls={[
              <Button
                onClick={() => showEditUserModal(values.username)}
                intent='secondary'
                disabled={!allowEdit || BUILT_IN_USERS.includes(values.username)}
                icon={IconEdit}
              />,
              <Button
                onClick={() => showRemoveUserModal(values.username)}
                intent='secondary'
                disabled={!allowDelete || BUILT_IN_USERS.includes(values.username)}
                icon={IconBucket}
              />
            ]}
          />
        );
      }
    }
  ])
);

class UsersTable extends React.Component {
  componentDidMount() {
    this.props.getUsersList();
  }

  componentWillUnmount() {
    this.props.resetUserState();
  }

  render() {
    const {
      items,
      implements_edit_user,
      implements_remove_user,
      loading,
      showEditUserModal,
      showRemoveUserModal
    } = this.props;

    return (
      <Table
        className={styles.table}
        columns={tableColumns(
          implements_edit_user,
          implements_remove_user,
          showEditUserModal,
          showRemoveUserModal
        )}
        data={items}
        loading={loading}
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
