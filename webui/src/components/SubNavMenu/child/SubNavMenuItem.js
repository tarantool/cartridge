import React from 'react';
import { NavLink } from 'react-router-dom';
import { css, cx } from 'emotion';

const styles = {
  item: css`
  `,
  link: css`
    display: block;
    padding: 13px;
    margin-bottom: 6px;
    font-size: 14px;
    border-radius: 4px;
    color: #343434;
    &:hover {
      color: #303030;
      background-color: rgba(52, 52, 52, 0.15);
    }
    &:focus {
      text-decoration: none;
      background-color: rgba(52, 52, 52, 0.15);
    }
    &:active {
      text-decoration: none;
    }
  `,
  linkActive: css`
    background-color: rgba(52, 52, 52, 0.3);
  `
};

const SubNavMenuItem = ({
  className,
  ...props
}) => (
    <li className={cx(className, styles.item)}>
      <NavLink className={styles.link} activeClassName={styles.linkActive} {...props} />
    </li>
  );

export default SubNavMenuItem;
