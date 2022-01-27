/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { IconInfo, Tooltip } from '@tarantool.io/ui-kit';

import { Maybe } from 'src/models';

import { states, styles } from './ReplicasetListStatus.styles';

export interface ReplicasetListStatusProps {
  status: string;
  message?: Maybe<string>;
  statusMessage?: Maybe<string>;
}

const ReplicasetListStatus = ({ status, statusMessage, message }: ReplicasetListStatusProps) => {
  const state = status.toLocaleLowerCase() === 'healthy' ? 'good' : 'bad';
  const label = statusMessage || status;

  if (!status || !label) {
    return null;
  }

  return (
    <div
      className={cx(styles.root, states[state])}
      data-component="ReplicasetListStatus"
      data-value-status={status}
      data-value-message={message}
    >
      <span className={styles.label}>{label}</span>
      {message && (
        <Tooltip content={message}>
          <IconInfo className={styles.icon} />
        </Tooltip>
      )}
    </div>
  );
};

export default memo(ReplicasetListStatus);
