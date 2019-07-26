import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import UsersTable from './UsersTable';
import PageSectionHead, { HeadButton } from 'src/components/PageSectionHead';
import UserAddModal from 'src/components/UserAddModal';
import UserEditModal from 'src/components/UserEditModal';
import UserRemoveModal from 'src/components/UserRemoveModal';
import AuthToggleButton from 'src/components/AuthToggleButton';
import { showAddUserModal } from 'src/store/actions/users.actions';

const styles = {
  cardMargin: css`
    padding-top: 24px;
    padding-bottom: 24px;
  `
}

const Users = ({
  implements_check_password,
  implements_add_user,
  implements_list_users,
  showAddUserModal
}) => (
  <div className={cx(styles.cardMargin, 'app-content')}>
    <UserRemoveModal />
    {implements_add_user && <UserAddModal />}
    <UserEditModal />
    <PageSectionHead
      title="Users list"
      buttons={[
        implements_check_password && <AuthToggleButton />,
        implements_add_user && <HeadButton onClick={showAddUserModal}>Add user</HeadButton>
      ]}
    />
    {implements_list_users && <UsersTable />}
  </div>
);

const mapStateToProps = ({
  app: {
    authParams: {
      implements_add_user,
      implements_check_password,
      implements_list_users
    }
  },
}) => ({
  implements_add_user,
  implements_check_password,
  implements_list_users
});

export default connect(mapStateToProps, { showAddUserModal })(Users);
