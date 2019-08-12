import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import * as R from 'ramda';
import {
  getUsersList,
  resetUserState,
  showEditUserModal,
  showRemoveUserModal
} from 'src/store/actions/users.actions';
import { TiledList } from '@tarantool.io/ui-kit';
import Dropdown from './Dropdown';
import NoData from './NoData';

const styles = {
  clickableRow: css`
    cursor: pointer;
  `,
  row: css`
    display: flex;
    flex-direction: row;
    flex-wrap: nowrap;
  `,
  username: css`
    font-size: 16px;
    font-weight: 600;
  `,
  field: css`
    width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-grow: 0;
    flex-shrink: 0;
    font-size: 14px;
    font-family: Open Sans;
    line-height: 22px;
    color: #000000;
  `,
  actions: css`
    margin-left: auto;
  `
};

const columns = [
  {
    title: 'Username',
    dataIndex: 'username',
    className: styles.username
  },
  {
    title: 'Full name',
    dataIndex: 'fullname',
    key: 'fullname'
  },
  {
    title: 'E-mail',
    dataIndex: 'email'
  }
];

const buttons = {
  edit: {
    text: 'Edit user',
    handler: ({ item, showEditUserModal }) => showEditUserModal(item.username)
  },
  remove: {
    text: 'Remove user',
    handler: ({ item, showRemoveUserModal }) => showRemoveUserModal(item.username),
    color: 'rgba(245, 34, 45, 0.65)'
  }
}

class UsersTable extends React.Component {


  componentDidMount() {
    this.props.getUsersList();
  }

  componentWillUnmount() {
    this.props.resetUserState();
  }

  handleRow = item => this.props.implements_edit_user && this.props.showEditUserModal(item.username)

  render() {
    const {
      items,
      implements_edit_user,
      implements_remove_user,
      showEditUserModal,
      showRemoveUserModal
    } = this.props;

    const actionButtons = (edit, remove) => (item, className) => {
      const filtered = R.compose(
        R.map(({ handler, ...rest }) => ({
          ...rest,
          onClick: () => handler({ item, showEditUserModal, showRemoveUserModal })
        })),
        R.filter(R.identity),
        R.map(([key, exists]) => exists ? buttons[key] : null),
        R.toPairs,
      )({ edit, remove })
      return filtered.length > 0 ? <Dropdown className={className} items={filtered} size={'s'}/> : null
    }

    const actionButton = actionButtons(implements_edit_user, implements_remove_user)

    return items.length ? (
      <TiledList
        className='meta-test__UsersTable'
        itemRender={item =>
          <div
            className={styles.row}
          >
            {columns.map(({ dataIndex, className }) =>
              <div className={cx(styles.field, className,)} title={item[dataIndex]}>{item[dataIndex]}</div>
            )}
            {
              actionButton(item, styles.actions)
            }
          </div>}
        items={items}
        columns={implements_edit_user || implements_remove_user ? this.columnsWithActions : this.columns}
        dataSource={items}
        itemKey='username'
        outer={false}
      />
    ) : (
      <NoData />
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
