import graphql from 'src/api/graphql';
import { addUserMutation, editUserMutation, fetchUsersQuery, removeUserMutation } from './queries.graphql';

export function getUserList() {
  return graphql.fetch(fetchUsersQuery)
    .then(({ cluster }) => ({
      items: cluster.users
    }));
}

export function addUser({
  email,
  fullname,
  password,
  username
}) {
  return graphql.mutate(addUserMutation, {
    email, fullname, password, username
  })
    .then(({ cluster }) => ({
      user: cluster.add_user
    }));
}

export function editUser({
  email,
  fullname,
  password,
  username
}) {
  return graphql.mutate(editUserMutation, {
    email, fullname, password: password || undefined, username
  })
    .then(({ cluster }) => ({
      user: cluster.edit_user
    }));
}

export function removeUser(username) {
  return graphql.mutate(removeUserMutation, { username })
    .then(({ cluster }) => ({
      user: cluster.remove_user
    }));
}
