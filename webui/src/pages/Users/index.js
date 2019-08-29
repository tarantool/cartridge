import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import UsersTable from '../../components/UsersTable';
import SpinnerLoader from '../../components/SpinnerLoader';
import PageSectionHead, { HeadButton } from 'src/components/PageSectionHead';
import PageSection from 'src/components/PageSection';
import UserAddModal from 'src/components/UserAddModal';
import UserEditModal from 'src/components/UserEditModal';
import UserRemoveModal from 'src/components/UserRemoveModal';
import AuthToggleButton from 'src/components/AuthToggleButton';
import { showAddUserModal } from 'src/store/actions/users.actions';
import Text from '../../components/Text';
import Button from '../../components/Button';

const { AppTitle } = window.tarantool_enterprise_core.components;

const styles = {
  cardMargin: css`
    padding: 24px 16px;
    min-width: 1000px;
  `,
  title: css`
    margin-left: 16px;
  `,
  buttons: css`
    display: flex;
    justify-content: flex-end;
  `,
  buttonMargin: css`
    margin-right: 24px;
    &:last-child {
      margin-right: 0;
    }
  `
}

const Users = ({
  fetchingUserList,
  implements_check_password,
  implements_add_user,
  implements_list_users,
  showAddUserModal,
}) => (
  <SpinnerLoader loading={fetchingUserList}>
    <div className={cx(styles.cardMargin, 'app-content')}>
      <AppTitle title={'Users'}/>
      <div className={styles.buttons}>
        {implements_check_password && <AuthToggleButton className={styles.buttonMargin} />}
        {implements_add_user && (
          <Button
            text={'Add user'}
            intent={'primary'}
            onClick={showAddUserModal}
          >
            Add user
          </Button>
        )}
      </div>
      <Text variant={'h2'} className={styles.title}>User List</Text>
      {implements_list_users && <UsersTable />}
      <UserRemoveModal />
      {implements_add_user && <UserAddModal />}
      <UserEditModal />
    </div>
  </SpinnerLoader>
);

const mapStateToProps = ({
  app: {
    authParams: {
      implements_add_user,
      implements_check_password,
      implements_list_users
    }
  },
  ui: {
    fetchingUserList
  }
}) => ({
  implements_add_user,
  implements_check_password,
  implements_list_users,
  fetchingUserList,
});

export default connect(mapStateToProps, { showAddUserModal })(Users);
