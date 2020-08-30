// @flow
import React from 'react';
import { connect } from 'react-redux';
import { Button, PageLayout } from '@tarantool.io/ui-kit';
import UsersTable from '../../components/UsersTable';
import SpinnerLoader from '../../components/SpinnerLoader';
import UserAddModal from 'src/components/UserAddModal';
import UserEditModal from 'src/components/UserEditModal';
import UserRemoveModal from 'src/components/UserRemoveModal';
import AuthToggleButton from 'src/components/AuthToggleButton';
import { showAddUserModal } from 'src/store/actions/users.actions';

const { AppTitle } = window.tarantool_enterprise_core.components;

type UsersProps = {
  fetchingUserList: boolean,
  implements_add_user: boolean,
  implements_list_users: boolean,
  showAddUserModal: boolean,
  showToggleAuth: boolean
};

const Users = ({
  fetchingUserList,
  implements_add_user,
  implements_list_users,
  showAddUserModal,
  showToggleAuth
}: UsersProps) => (
  <PageLayout
    heading='Users'
    controls={[
      showToggleAuth && <AuthToggleButton />,
      implements_add_user && (
        <Button
          className='meta-test__addUserBtn'
          text='Add user'
          intent='primary'
          onClick={showAddUserModal}
          size='l'
        >
          Add user
        </Button>
      )
    ]}
  >
    <AppTitle title='Users' />
    <SpinnerLoader loading={fetchingUserList}>
      {implements_list_users && <UsersTable />}
      <UserRemoveModal />
      {implements_add_user && <UserAddModal />}
      <UserEditModal />
    </SpinnerLoader>
  </PageLayout>
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
  showToggleAuth: implements_check_password && (implements_add_user || implements_list_users),
  implements_list_users,
  fetchingUserList
});

export default connect(mapStateToProps, { showAddUserModal })(Users);
