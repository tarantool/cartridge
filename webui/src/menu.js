// @flow
import React from 'react';
import { css } from '@emotion/css';
import { core } from '@tarantool.io/frontend-core';
import { IconCluster, IconCode, IconGear, IconUsers } from '@tarantool.io/ui-kit';
import type { MenuItemType } from '@tarantool.io/ui-kit';

import { PROJECT_NAME } from './constants';

const matchPath = (path, link) => {
  if (path.length === 0) return false;
  const point = path.indexOf(link);
  return point === 0 && (link.length === path.length || path[link.length] === '/');
};

const updateLink = (path) => (menuItem) => ({ ...menuItem, selected: matchPath(path, menuItem.path) });

const menuItems = {
  cluster(enableUsersItem: ?boolean, enableMigrationsItem: ?boolean) {
    return [
      {
        label: 'Cluster',
        path: `/${PROJECT_NAME}/dashboard`,
        selected: false,
        expanded: false,
        loading: false,
        icon: <IconCluster />,
      },
      ...(enableUsersItem
        ? [
            {
              label: 'Users',
              path: `/${PROJECT_NAME}/users`,
              selected: false,
              expanded: false,
              loading: false,
              icon: <IconUsers />,
            },
          ]
        : []),
      {
        label: 'Configuration files',
        path: `/${PROJECT_NAME}/configuration`,
        selected: false,
        expanded: false,
        loading: false,
        icon: (
          <IconGear
            className={css`
              width: 14px;
              height: 14px;
              fill: #fff;
            `}
          />
        ),
      },
      {
        label: 'Code',
        path: `/${PROJECT_NAME}/code`,
        selected: false,
        expanded: false,
        loading: false,
        icon: (
          <IconCode
            className={css`
              width: 14px;
              height: 14px;
              fill: #fff;
            `}
          />
        ),
      },
      ...(enableMigrationsItem
        ? [
            {
              label: 'Migrations',
              path: `/${PROJECT_NAME}/migrations`,
              selected: false,
              expanded: false,
              loading: false,
              icon: <IconCluster />,
            },
          ]
        : []),
    ];
  },
};

const menuInitialState = menuItems.cluster();

export const menuReducer = (state: MenuItemType[] = menuInitialState, { type, payload }: FSA): MenuItemType[] => {
  switch (type) {
    case 'UPDATE_CLUSTER_MENU_ITEMS': {
      if (payload && payload.location) {
        return menuItems.cluster(payload.users, payload.migrations).map(updateLink(payload.location.pathname || ''));
      }

      return state;
    }

    case '@@router/LOCATION_CHANGE': {
      if (payload && payload.location && payload.location.pathname) {
        return state.map(updateLink(payload.location.pathname));
      }

      return state;
    }

    case 'RESET': {
      if (payload) {
        return menuInitialState.map(updateLink(payload.path));
      }

      return state;
    }

    default:
      return state;
  }
};

const createMenuFilter = () => {
  const generateFilter =
    (isMenuVisible: boolean, hiddenPaths: string[]) =>
    (item: MenuItemType): boolean => {
      if (!isMenuVisible || !item) return false;
      return !hiddenPaths.some((i) => i === item.path);
    };

  let unregisterCurrentFilter = null;

  const changeFilter = (filter: Function) => {
    const unregisterFilter = core.pageFilter.registerFilter(filter);
    // dispose current filter
    if (unregisterCurrentFilter) {
      unregisterCurrentFilter();
    }
    unregisterCurrentFilter = unregisterFilter;
  };

  return {
    set(newPaths: string[]): void {
      changeFilter(generateFilter(true, newPaths));
    },
    hideAll(): void {
      changeFilter(generateFilter(false, []));
    },
  };
};

export const menuFilter = createMenuFilter();
