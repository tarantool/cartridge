import { PROJECT_NAME } from './constants';
import * as React from 'react'
import { css } from 'react-emotion'
import { IconUsers } from './components/Icon/icons/IconUsers';
import { IconGear } from './components/Icon/icons/IconGear';
import { IconCluster } from './components/Icon/icons/IconCluster';

const matchPath = (path, link) => {
  if (path.length === 0)
    return false;
  const point = path.indexOf(link);
  return point === 0 && (link.length === path.length || path[link.length] === '/')
}

const updateLink = path => menuItem => ({ ...menuItem, selected: matchPath(path, menuItem.path) })

const menuItems = {
  cluster() {
    return [
      {
        label: 'Cluster',
        path: `/${PROJECT_NAME}/dashboard`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconCluster />
      },
      {
        label: 'Users',
        path: `/${PROJECT_NAME}/users`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconGear className={css`width: 14px; height: 14px; fill: #fff;`} />
      },
      {
        label: 'Configuration files',
        path: `/${PROJECT_NAME}/configuration`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconUsers />
      }
    ]
  }
};

const menuInitialState = menuItems.cluster(true);

export const menuReducer = (state = menuInitialState, { type, payload }) => {
  switch (type) {
    case 'ADD_CLUSTER_USERS_MENU_ITEM':
      return menuItems.cluster(true).map(updateLink(payload.location.pathname));

    case '@@router/LOCATION_CHANGE':
      return state.map(updateLink(payload.location.pathname))

    case 'RESET':
      return menuInitialState.map(updateLink(payload.path))

    default:
      return state;
  }
};
