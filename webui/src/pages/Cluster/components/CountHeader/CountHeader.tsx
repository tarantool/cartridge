import React, { memo, useMemo } from 'react';

import { styles } from './CountHeader.styles';

export type CountHeaderDataType =
  | 'total-replicasets'
  | 'unhealthy-replicasets'
  | 'total-instances'
  | 'unhealthy-instances'
  | 'unconfigured-instances';

export interface CountHeaderProps {
  ['data-type']: CountHeaderDataType;
  counter: number;
}

const labels: Record<CountHeaderDataType, string> = {
  'total-replicasets': 'Total replicasets',
  'unhealthy-replicasets': 'Unhealthy replicasets',
  'total-instances': 'Total instances',
  'unhealthy-instances': 'Unhealthy instances',
  'unconfigured-instances': 'Total unconfigured instances',
};

export const CountHeader = memo(({ counter, ['data-type']: dt }: CountHeaderProps) => {
  const label = useMemo(() => {
    return labels[dt] ?? '';
  }, [dt]);

  if (!label) {
    return null;
  }

  return (
    <span className={styles.root} data-component="CountHeader">
      <span className={styles.label} data-type={dt} data-count={counter}>
        {label}
      </span>
      <span className={styles.counter}>{counter}</span>
    </span>
  );
});
