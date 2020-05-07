// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  sample
} from 'effector';
import type { User, AddUserMutationVariables, EditUserMutationVariables } from 'src/generated/graphql-typing';
import { addUser, editUser, getUserList, removeUser } from 'src/store/request/users.requests';

type VisibleModalType = null | 'add' | 'edit' | 'remove';

type UsersList = User[];

export default () => {
  const resetUsersList = createEvent<void>('reset users');
  const showUserAddModal = createEvent<void>('show user add modal');
  const showUserEditModal = createEvent<string>('show user edit modal');
  const showUserRemoveModal = createEvent<string>('show user remove modal');
  const hideModal = createEvent<void>('hide user edit modal');

  const $usersList = createStore<UsersList>([]);
  const $usersListFetchError = createStore<null | string>(null);
  const $userMutationError = createStore<null | string>(null);

  const $usernameToMutate = createStore<null | string>(null);
  const $userToMutate = sample<UsersList, null | string, ?User>(
    $usersList,
    $usernameToMutate,
    (users, username) => users.find(user => user.username === username) || null
  );

  const $visibleModal = createStore<VisibleModalType>(null);

  const $userAddModal = createStoreObject({
    visible: $visibleModal.map(f => f === 'add'),
    error: $userMutationError
  });

  const $userEditModal = createStoreObject({
    username: $usernameToMutate,
    visible: $visibleModal.map(f => f === 'edit'),
    error: $userMutationError
  });

  const $userRemoveModal = createStoreObject({
    username: $usernameToMutate,
    visible: $visibleModal.map(f => f === 'remove'),
    error: $userMutationError
  });

  const fetchUsersListFx = createEffect<void, UsersList, string>({
    handler: async () => {
      const { items } = await getUserList();
      return items;
    }
  });

  const removeUserFx = createEffect<string, void, string>({
    handler: async (username: string) => await removeUser(username)
  });

  const addUserFx = createEffect<AddUserMutationVariables, void, string>({
    handler: async user => await addUser(user)
  });
  const editUserFx = createEffect<EditUserMutationVariables, void, string>({
    handler: async user => await editUser(user)
  });

  return {
    $usernameToMutate,
    $visibleModal,
    $userToMutate,
    $userAddModal,
    $userEditModal,
    $userRemoveModal,
    $usersList,
    $usersListFetchError,
    $userMutationError,
    showUserAddModal,
    showUserEditModal,
    showUserRemoveModal,
    hideModal,
    fetchUsersListFx,
    addUserFx,
    editUserFx,
    removeUserFx,
    resetUsersList
  };
}