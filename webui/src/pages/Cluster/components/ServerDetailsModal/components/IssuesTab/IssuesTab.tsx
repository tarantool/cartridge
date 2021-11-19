import React, { memo } from 'react';
import { Text } from '@tarantool.io/ui-kit';

import type { ServerListServerClusterIssue } from 'src/models';

import { styles } from './IssuesTab.styles';

export interface IssuesTabProps {
  issues: ServerListServerClusterIssue[];
}

const IssuesTab = ({ issues }: IssuesTabProps) => {
  return (
    <ul className={styles.list}>
      {issues.map(({ level, message }, index) => (
        <li key={index} className={styles.listItem}>
          <Text className={styles.listItemHeading}>{level}</Text>
          <Text tag="p">{message}</Text>
        </li>
      ))}
    </ul>
  );
};

export default memo(IssuesTab);
