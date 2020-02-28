// @flow
import { PROJECT_NAME } from './constants';
import * as React from 'react';
import { css } from 'react-emotion';
import {
  IconCluster,
  IconCode,
  IconGear,
  IconSchema,
  IconUsers,
  type MenuItemType
} from '@tarantool.io/ui-kit';

const matchPath = (path, link) => {
  if (path.length === 0)
    return false;
  const point = path.indexOf(link);
  return point === 0 && (link.length === path.length || path[link.length] === '/')
}

const updateLink = path => menuItem => ({ ...menuItem, selected: matchPath(path, menuItem.path) })

const menuItems = {
  cluster(enableUsersItem: ?boolean) {
    return [
      {
        label: 'Cluster',
        path: `/${PROJECT_NAME}/dashboard`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconCluster />
      },
      ...enableUsersItem
        ? [{
          label: 'Users',
          path: `/${PROJECT_NAME}/users`,
          selected: false,
          expanded: false,
          loading: false,
          icon: <IconUsers />
        }]
        : [],
      {
        label: 'Configuration files',
        path: `/${PROJECT_NAME}/configuration`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconGear className={css`width: 14px; height: 14px; fill: #fff;`} />
      },
      {
        label: 'Code',
        path: `/${PROJECT_NAME}/code`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconCode className={css`width: 14px; height: 14px; fill: #fff;`} />
      },
      {
        label: 'Schema',
        path: `/${PROJECT_NAME}/schema`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconSchema className={css`width: 14px; height: 14px; fill: #fff;`} />
      }
    ]
  }
};

const menuInitialState = menuItems.cluster();

export const menuReducer = (state: MenuItemType[] = menuInitialState, { type, payload }: FSA): MenuItemType[] => {
  switch (type) {
    case 'ADD_CLUSTER_USERS_MENU_ITEM':
      if (payload && payload.location && payload.location.pathname) {
        return menuItems.cluster(true).map(updateLink(payload.location.pathname));
      } else {
        return state;
      }

    case '@@router/LOCATION_CHANGE':
      if (payload && payload.location && payload.location.pathname) {
        return state.map(updateLink(payload.location.pathname))
      } else {
        return state;
      }

    case 'RESET':
      if (payload) {
        return menuInitialState.map(updateLink(payload.path))
      } else {
        return state;
      }

    default:
      return state;
  }
};

const createMenuFilter = () => {
  let isMenuVisible = false;
  let hiddenPaths: string[] = [];

  return {
    check(item: MenuItemType) {
      if (!isMenuVisible || !item) return false;
      return !hiddenPaths.some(i => i === item.path);
    },
    set(newPaths: string[]): void {
      hiddenPaths = newPaths;
      isMenuVisible = true;
    },
    hideAll(): void {
      isMenuVisible = false;
    }
  }
}

export const menuFilter = createMenuFilter();
