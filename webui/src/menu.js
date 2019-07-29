import { PROJECT_NAME } from './constants';

const matchPath = (path, link) => {
  if (path.length === 0)
    return false;
  const point = path.indexOf(link);
  return point === 0 && (link.length === path.length || path[link.length] === '/')
}

const updateLink = path => menuItem => ({ ...menuItem, selected: matchPath(path, menuItem.path) })

const menuItems = {
  users() {
    return {
      label: 'Users',
      path: `/${PROJECT_NAME}/users`,
      selected: false,
      expanded: false,
      loading: false,
      items: []
    }
  },
  cluster(showUsers = false) {
    return {
      label: 'Cluster',
      path: `/${PROJECT_NAME}`,
      selected: false,
      expanded: true,
      loading: false,
      items: showUsers ? [this.users()] : []
    }
  }
};

const menuInitialState = [menuItems.cluster()];

export const menuReducer = (state = menuInitialState, { type, payload }) => {
  switch (type) {
    case 'ADD_CLUSTER_USERS_MENU_ITEM':
      return [menuItems.cluster(true)].map(updateLink(payload.location.pathname));

    case '@@router/LOCATION_CHANGE':
      return state.map(updateLink(payload.location.pathname))

    case 'RESET':
      return menuInitialState.map(updateLink(payload.path))

    default:
      return state;
  }
};
