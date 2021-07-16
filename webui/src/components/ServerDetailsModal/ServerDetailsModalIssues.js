// @flow
import React from 'react';
import { Text } from '@tarantool.io/ui-kit';
import { css } from '@emotion/css';
import type { Issue } from 'src/generated/graphql-typing';

const styles = {
  list: css`
    padding: 0;
    margin: 20px 0 0;
    list-style: none;
  `,
  listItem: css`
    margin-bottom: 23px;
  `,
  listItemHeading: css`
    display: block;
    font-weight: 600;
    text-transform: capitalize;
  `
};

type Props = { issues: Issue[] };

export const ServerDetailsModalIssues = ({ issues }: Props) => {
  return (
    <ul className={styles.list}>
      {issues.map(({ level, message }, index) => (
        <li className={styles.listItem}>
          <Text className={styles.listItemHeading}>{level}</Text>
          <Text tag='p'>{message}</Text>
        </li>
      ))}
    </ul>
  );
};
