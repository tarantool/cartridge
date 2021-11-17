import React from 'react';
import { cx } from '@emotion/css';
import { Text } from '@tarantool.io/ui-kit';

import { states, styles } from './HealthStatus.styles';

export interface HealthStatusProps {
  className?: string;
  defaultMessage?: string;
  status?: string;
  message?: string;
  title?: string;
}

const HealthStatus = ({ className, defaultMessage, status, message, title }: HealthStatusProps) => {
  const state = status === 'healthy' ? 'good' : 'bad';

  return (
    <Text className={cx(styles.status, states[state], className)} variant="h5" tag="div" title={title}>
      {message || defaultMessage || status}
    </Text>
  );
};

export default HealthStatus;
