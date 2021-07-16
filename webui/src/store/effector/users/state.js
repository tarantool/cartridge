// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  type Store
} from 'effector';
import type { User, AddUserMutationVariables, EditUserMutationVariables } from 'src/generated/graphql-typing';
import { addUser, editUser, getUserList, removeUser } from 'src/store/request/users.requests';

type VisibleModalType = null | 'add' | 'edit' | 'remove';

export type UsersList = User[];

export const resetUsersList = createEvent<void>('reset users');
export const showUserAddModal = createEvent<void>('show user add modal');
export const showUserEditModal = createEvent<string>('show user edit modal');
export const showUserRemoveModal = createEvent<string>('show user remove modal');
export const hideModal = createEvent<void>('hide user edit modal');

export const $usersList: Store<UsersList> = createStore<UsersList>([]);
export const $usersListFetchError = createStore<null | string>(null);
export const $userMutationError = createStore<null | string>(null);

export const $usernameToMutate = createStore<null | string>(null);
export const $visibleModal = createStore<VisibleModalType>(null);

export const $userAddModal = createStoreObject({
  visible: $visibleModal.map(f => f === 'add'),
  error: $userMutationError
});

export const $userEditModal = createStoreObject({
  username: $usernameToMutate,
  visible: $visibleModal.map(f => f === 'edit'),
  error: $userMutationError
});

export const $userRemoveModal = createStoreObject({
  username: $usernameToMutate,
  visible: $visibleModal.map(f => f === 'remove'),
  error: $userMutationError
});

export const fetchUsersListFx = createEffect<mixed, UsersList, string>({
  handler: async () => {
    const { items } = await getUserList();
    return items;
  }
});

export const removeUserFx = createEffect<string, void, string>({
  handler: async (username: string) => await removeUser(username)
});

export const addUserFx = createEffect<AddUserMutationVariables, void, string>({
  handler: async user => await addUser(user)
});
export const editUserFx = createEffect<EditUserMutationVariables, void, string>({
  handler: async user => await editUser(user)
});
