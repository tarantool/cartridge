// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import DotIndicator from 'src/components/DotIndicator';
import Text from 'src/components/Text';

const styles = {
  status: css`
    display: flex;
    align-items: baseline;
    flex-basis: 153px;
  `
};

type HealthStatusProps = {
  className?: string,
  status?: string,
  message?: string
};

const HealthStatus = ({
  className,
  status,
  message
}:
HealthStatusProps) => (
  <Text className={cx(styles.status, className)} variant='p'>
    <DotIndicator state={status === 'healthy' ? 'good' : 'bad'} />
    {message || status}
  </Text>
);

export default HealthStatus;
