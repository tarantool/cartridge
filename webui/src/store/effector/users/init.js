import { forward } from 'effector';
import { getGraphqlErrorMessage } from 'src/api/graphql';

export default ({
  $inputUsername,
  $inputPassword,
  $inputEmail,
  $inputFullName,
  $usernameToMutate,
  $visibleModal,
  $usersList,
  $usersListFetchError,
  $userMutationError,
  $userToMutate,
  changeUsername,
  changePassword,
  changeEmail,
  changeFullName,
  hideModal,
  showUserAddModal,
  showUserEditModal,
  showUserRemoveModal,
  fetchUsersListFx,
  addUserFx,
  editUserFx,
  removeUserFx,
  resetUsersList
}) => {
  $usersList
    .on(fetchUsersListFx.doneData, (_, items) => items)
    .reset(fetchUsersListFx.failData)
    .reset(resetUsersList);

  $usersListFetchError
    .on(fetchUsersListFx.failData, (_, error) => getGraphqlErrorMessage(error))
    .reset(fetchUsersListFx.done)
    .reset(resetUsersList);

  $userMutationError
    .on(addUserFx.failData, (_, error) => getGraphqlErrorMessage(error))
    .on(editUserFx.failData, (_, error) => getGraphqlErrorMessage(error))
    .on(removeUserFx.failData, (_, error) => getGraphqlErrorMessage(error))
    .reset(addUserFx)
    .reset(editUserFx)
    .reset(removeUserFx)
    .reset(addUserFx.done)
    .reset(editUserFx.done)
    .reset(removeUserFx.done)
    .reset($visibleModal);

  $usernameToMutate
    .on(showUserEditModal, (_, username) => username)
    .on(showUserRemoveModal, (_, username) => username)
    .reset(showUserAddModal)
    .reset(hideModal);

  $visibleModal
    .on(showUserAddModal, () => 'add')
    .on(showUserEditModal, () => 'edit')
    .on(showUserRemoveModal, () => 'remove')
    .reset(addUserFx.done)
    .reset(editUserFx.done)
    .reset(removeUserFx.done)
    .reset(hideModal);

  forward({ from: addUserFx.done, to: fetchUsersListFx });
  forward({ from: editUserFx.done, to: fetchUsersListFx });
  forward({ from: removeUserFx.done, to: fetchUsersListFx });
}
