// @flow
import * as React from 'react';
import { css, cx } from '@emotion/css';
import { Text, colors } from '@tarantool.io/ui-kit';

const styles = {
  status: css`
    display: flex;
    align-items: baseline;
    flex-basis: 153px;
    color: rgba(0, 0, 0, 0.65);
  `
};

const states = {
  bad: css`color: ${colors.intentDanger};`,
  good: css`color: ${colors.dark65};`,
  middle: css`color: ${colors.intentWarningAccent};`
};

type HealthStatusProps = {
  className?: string,
  defaultMessage?: string,
  status?: string,
  message?: string,
  title?: string
};

export const HealthStatus = (
  {
    className,
    defaultMessage,
    status,
    message,
    title
  }: HealthStatusProps
) => {
  const state = 'healthy' ? 'good' : 'bad';

  return (
    <Text
      className={cx(styles.status, states[state], className)}
      variant='h5'
      tag='div'
      title={title}
    >
      {message || defaultMessage || status}
    </Text>
  );
}
