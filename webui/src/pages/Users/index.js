// @flow
import React from 'react';
import { connect } from 'react-redux';
import { Button } from '@tarantool.io/ui-kit';
import { PageLayout } from 'src/components/PageLayout';
import { UsersTable } from '../../components/UsersTable';
import { UserAddModal } from 'src/components/UserAddModal';
import { UserEditModal } from 'src/components/UserEditModal';
import { UserRemoveModal } from 'src/components/UserRemoveModal';
import AuthToggleButton from 'src/components/AuthToggleButton';
import { showUserAddModal } from 'src/store/effector/users';

const { AppTitle } = window.tarantool_enterprise_core.components;

type UsersProps = {
  implements_add_user: boolean,
  implements_list_users: boolean,
  implements_remove_user: boolean,
  implements_edit_user: boolean,
  showToggleAuth: boolean
};

const Users = ({
  implements_add_user,
  implements_list_users,
  implements_edit_user,
  implements_remove_user,
  showToggleAuth
}: UsersProps) => (
  <PageLayout
    heading='Users'
    topRightControls={[
      showToggleAuth && <AuthToggleButton />,
      implements_add_user && (
        <Button
          className='meta-test__addUserBtn'
          text='Add user'
          intent='primary'
          onClick={showUserAddModal}
          size='l'
        >
          Add user
        </Button>
      )
    ]}
  >
    <AppTitle title='Users' />
    {implements_list_users && (
      <UsersTable
        implements_edit_user={implements_edit_user}
        implements_remove_user={implements_remove_user}
      />
    )}
    <UserRemoveModal />
    {implements_add_user && <UserAddModal />}
    <UserEditModal />
  </PageLayout>
);

const mapStateToProps = ({
  app: {
    authParams: {
      implements_add_user,
      implements_check_password,
      implements_list_users,
      implements_remove_user,
      implements_edit_user
    }
  }
}) => ({
  implements_add_user,
  showToggleAuth: implements_check_password && (implements_add_user || implements_list_users),
  implements_list_users,
  implements_remove_user,
  implements_edit_user
});

export default connect(mapStateToProps)(Users);
