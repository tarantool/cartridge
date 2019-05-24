import graphql from 'src/api/graphql';

export function getUserList() {
  const graph = `
    query {
      cluster {
        users {
          username
          fullname
          email
        }
      }
    }
  `;

  return graphql.fetch(graph)
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
  const graph = `
    mutation {
      cluster {
        add_user(
          username: "${username}"
          password: "${password}"
          email: "${email}"
          fullname: "${fullname}"
        ) {
          username
          email
          fullname
        }
      }
    }
  `;

  return graphql.fetch(graph)
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
  const graph = `
    mutation {
      cluster {
        edit_user(
          username: "${username}"
          ${password ? `password: "${password}"` : ''}
          email: "${email}"
          fullname: "${fullname}"
        ) {
          username
          email
          fullname
        }
      }
    }
  `;

  return graphql.fetch(graph)
    .then(({ cluster }) => ({
      user: cluster.edit_user
    }));
}

export function removeUser(username) {
  const graph = `
    mutation {
      cluster {
        remove_user(username: "${username}") {
          username
          email
          fullname
        }
      }
    }
  `;

  return graphql.fetch(graph)
    .then(({ cluster }) => ({
      user: cluster.remove_user
    }));
}