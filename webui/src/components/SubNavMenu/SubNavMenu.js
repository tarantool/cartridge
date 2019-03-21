import React from 'react';
import { css, cx } from 'emotion';
import Item from './child/SubNavMenuItem';

const styles = {
  menu: css`
    padding: 0;
    margin: 0;
    list-style: none;
  `,
};

const SubNavMenu = ({ className, children }) => (
  <ul className={cx(className, styles.menu)}>
    {children}
  </ul>
);

SubNavMenu.Item = Item;

export default SubNavMenu;
