import React from 'react';
import { css } from '@emotion/css';

import { MigrationsMoveButton } from './MigrationsMoveButton';
import { MigrationsRefresh } from './MigrationsRefresh';
import { MigrationsState } from './MigrationsState';
import { MigrationsUpButton } from './MigrationsUpButton';

export const styles = {
  root: css``,
  content: css`
    margin-top: 12px;
  `,
  actions: css`
    display: flex;
    align-items: center;
    gap: 12px;
  `,
  div: css`
    flex: 1 1 auto;
  `,
};

export const Migrations = () => {
  return (
    <div className={styles.root}>
      <div className={styles.actions}>
        <MigrationsRefresh />
        <MigrationsUpButton />
        <div className={styles.div} />
        <MigrationsMoveButton />
      </div>
      <div className={styles.content}>
        <MigrationsState />
      </div>
    </div>
  );
};
