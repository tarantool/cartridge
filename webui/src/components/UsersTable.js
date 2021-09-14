// @flow
import React from 'react';
import { css, cx } from '@emotion/css';
import { useStore } from 'effector-react';
import { identity, memoizeWith } from 'ramda';
import { Button, ControlsPanel, IconBucket, IconEdit, Link, Table, colors } from '@tarantool.io/ui-kit';

import { BUILT_IN_USERS } from 'src/constants';
import { $usersList, fetchUsersListFx, showUserEditModal, showUserRemoveModal } from 'src/store/effector/users';

const styles = {
  table: css`
    table-layout: fixed;

    th:last-child {
      width: 10%;
    }

    td {
      overflow: hidden;
      text-overflow: ellipsis;
    }
  `,
  loading: css`
    background: white;
    height: 200px;
    thead {
      background: ${colors.baseBg};
    }
  `,
  noDataState: css`
    height: calc(100vh - 175px);
    th {
      display: none;
    }
  `,
  tableLink: css`
    color: ${colors.dark};
    font-weight: 600;
    text-decoration: none;

    &:hover,
    &:focus {
      text-decoration: underline;
    }
  `,
  tableLinkDisabled: css`
    cursor: default;
    text-decoration: none;

    &:hover,
    &:focus {
      text-decoration: none;
    }
  `,
};

const tableColumns = memoizeWith(identity, (allowEdit, allowDelete) => [
  {
    Header: 'Username',
    accessor: 'username',
    Cell: ({ cell: { value } }) => (
      <Link
        href="#"
        className={cx(styles.tableLink, { [styles.tableLinkDisabled]: !allowEdit || BUILT_IN_USERS.includes(value) })}
        tabIndex={(!allowEdit || BUILT_IN_USERS.includes(value)) && -1}
        onClick={(e) => {
          e.preventDefault();
          if (allowEdit && !BUILT_IN_USERS.includes(value)) showUserEditModal(value);
        }}
      >
        {value}
      </Link>
    ),
  },
  {
    Header: 'Full name',
    accessor: 'fullname',
    Cell: ({ cell: { value } }) => value || '—',
  },
  {
    Header: 'E-mail',
    accessor: 'email',
    Cell: ({ cell: { value } }) => value || '—',
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
              key="edit"
              onClick={() => showUserEditModal(values.username)}
              intent="secondary"
              disabled={!allowEdit || BUILT_IN_USERS.includes(values.username)}
              icon={IconEdit}
            />,
            <Button
              key="bucket"
              onClick={() => showUserRemoveModal(values.username)}
              intent="secondary"
              disabled={!allowDelete || BUILT_IN_USERS.includes(values.username)}
              icon={IconBucket}
            />,
          ]}
        />
      );
    },
  },
]);

type UsersTableProps = {
  implements_edit_user: boolean,
  implements_remove_user: boolean,
};

export const UsersTable = ({ implements_edit_user, implements_remove_user }: UsersTableProps) => {
  const items = useStore($usersList);

  const fetching = useStore(fetchUsersListFx.pending);

  const noData = !fetching && !items.length;

  return (
    <Table
      className={cx(styles.table, { [styles.noDataState]: noData, [styles.loading]: fetching })}
      columns={tableColumns(implements_edit_user, implements_remove_user)}
      data={items}
      loading={fetching}
    />
  );
};
