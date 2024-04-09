/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Table } from '@tarantool.io/ui-kit';

import { migrations } from 'src/models';

const styles = {
  root: css``,
  pre: css`
    background: white;
    border-radius: 6px;
    padding: 12px;
  `,
};

const columns = [
  {
    Header: 'Instance',
    accessor: 'name',
  },
  {
    Header: 'Applied migrations',
    accessor: 'migrations',
    disableSortBy: true,
  },
];

export const MigrationsState = () => {
  const state = useStore(migrations.$migrationsState);
  const data = useMemo(
    () =>
      Object.keys(state?.applied ?? {}).reduce((acc: { name: string; migrations: string }[], key) => {
        const item = state?.applied?.[key];
        if (item) {
          acc.push({
            name: key,
            migrations: item.length > 0 ? item.join(', ') : '-',
          });
        }

        return acc;
      }, []),
    [state?.applied]
  );
  const withWarning = useMemo(
    () =>
      Object.keys(state?.applied ?? {}).reduce(
        (acc, key) => {
          if (!acc.result) {
            const item = state?.applied?.[key];
            if (item) {
              const hash = [...item].sort().join(',');
              acc.result = hash !== acc.hash;
              acc.hash = hash;
            }
          }

          return acc;
        },
        { result: false, hash: '' } as { result: boolean; hash: string }
      ).result,
    [state?.applied]
  );

  return (
    <div className={styles.root}>
      {withWarning && <Alert type="error">Migrations are not same on instances</Alert>}
      <Table columns={columns} data={data} />
    </div>
  );
};
