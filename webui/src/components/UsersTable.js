// @flow
import React, { useEffect } from 'react';
import { useStore } from 'effector-react';
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
import usersStore from 'src/store/effector/users';
import { BUILT_IN_USERS } from 'src/constants';

const {
  showUserEditModal,
  showUserRemoveModal,
  resetUsersList,
  fetchUsersListFx,
  $usersList
} = usersStore;

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
    allowDelete
  ) => ([
    {
      Header: 'Username',
      accessor: 'username',
      Cell: ({ cell: { value } }) => (
        <Link
          href='#'
          className={styles.username}
          onClick={e => { e.preventDefault(); showUserEditModal(value); }}
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
                onClick={() => showUserEditModal(values.username)}
                intent='secondary'
                disabled={!allowEdit || BUILT_IN_USERS.includes(values.username)}
                icon={IconEdit}
              />,
              <Button
                onClick={() => showUserRemoveModal(values.username)}
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

type UsersTableProps = {
  implements_edit_user: boolean,
  implements_remove_user: boolean
}

export const UsersTable = (
  {
    implements_edit_user,
    implements_remove_user
  }: UsersTableProps
) => {
  useEffect(
    () => {
      fetchUsersListFx();
      return resetUsersList;
    },
    []
  );

  const items = useStore($usersList);

  const fetching = useStore(fetchUsersListFx.pending);

  return (
    <Table
      className={styles.table}
      columns={tableColumns(
        implements_edit_user,
        implements_remove_user
      )}
      data={items}
      loading={fetching}
    />
  );
};
