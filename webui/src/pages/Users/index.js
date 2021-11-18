// @flow
import React, { useEffect } from 'react';
import { connect } from 'react-redux';
import { useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import AuthToggleButton from 'src/components/AuthToggleButton';
import { PageLayout } from 'src/components/PageLayout';
import { UserAddModal } from 'src/components/UserAddModal';
import { UserEditModal } from 'src/components/UserEditModal';
import { UserRemoveModal } from 'src/components/UserRemoveModal';
import { $usersListFetchError, fetchUsersListFx, resetUsersList, showUserAddModal } from 'src/store/effector/users';

import PageDataErrorMessage from '../../components/PageDataErrorMessage';
import { UsersTable } from '../../components/UsersTable';

const { AppTitle } = window.tarantool_enterprise_core.components;

type UsersProps = {
  implements_add_user: boolean,
  implements_list_users: boolean,
  implements_remove_user: boolean,
  implements_edit_user: boolean,
  showToggleAuth: boolean,
};

const Users = ({
  implements_add_user,
  implements_list_users,
  implements_edit_user,
  implements_remove_user,
  implements_check_password,
  showToggleAuth,
}: UsersProps) => {
  useEffect(() => {
    fetchUsersListFx();
    return resetUsersList;
  }, []);
  const usersListFetchError = useStore($usersListFetchError);

  if (usersListFetchError) {
    return <PageDataErrorMessage error={usersListFetchError} />;
  }

  return (
    <PageLayout
      heading="Users"
      topRightControls={[
        showToggleAuth && <AuthToggleButton key="auth" implements_check_password={implements_check_password} />,
        implements_add_user && (
          <Button
            key="add"
            className="meta-test__addUserBtn"
            text="Add user"
            intent="primary"
            onClick={showUserAddModal}
            size="l"
          >
            Add user
          </Button>
        ),
      ]}
    >
      <AppTitle title="Users" />
      {implements_list_users && (
        <UsersTable implements_edit_user={implements_edit_user} implements_remove_user={implements_remove_user} />
      )}
      <UserRemoveModal />
      {implements_add_user && <UserAddModal />}
      <UserEditModal />
    </PageLayout>
  );
};

const mapStateToProps = ({
  app: {
    authParams: {
      implements_add_user,
      implements_check_password,
      implements_list_users,
      implements_remove_user,
      implements_edit_user,
    },
  },
}) => ({
  implements_add_user,
  showToggleAuth: implements_check_password && (implements_add_user || implements_list_users),
  implements_list_users,
  implements_remove_user,
  implements_edit_user,
  implements_check_password,
});

export default connect(mapStateToProps)(Users);
