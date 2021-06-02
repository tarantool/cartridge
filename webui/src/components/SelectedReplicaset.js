// @flow
// TODO: split and move to uikit
import React from 'react';
import { css, cx } from '@emotion/css';
import type { Replicaset } from 'src/generated/graphql-typing';
import { HealthStatus, Text } from '@tarantool.io/ui-kit';

const styles = {
  replicaset: css`
    padding: 16px;
    background: #FFFFFF;
    border: 1px solid #E8E8E8;
    margin: 0 0 24px;
    box-sizing: border-box;
    box-shadow: 0px 1px 10px rgba(0, 0, 0, 0.06);
    border-radius: 4px;
  `,
  headingWrap: css`
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  `,
  alias: css`
    overflow: hidden;
    text-overflow: ellipsis;
  `,
  uuid: css`
    opacity: 0.65;
  `,
  status: css`
    flex-basis: 402px;
    margin-left: 24px;
  `
}

type SelectedReplicasetProps = {
  className?: string,
  replicaset?: Replicaset,
}

const SelectedReplicaset = ({ className, replicaset }: SelectedReplicasetProps) => {
  const {
    alias,
    status,
    uuid
  } = replicaset || {};

  return (
    <div className={cx(styles.replicaset, className)}>
      <div className={styles.headingWrap}>
        <Text className={styles.alias} variant='h3'>{alias || uuid}</Text>
        <HealthStatus className={styles.status} status={status}  />
      </div>
      <Text className={styles.uuid} variant='p' tag='span'>{`uuid: ${uuid}`}</Text>
    </div>
  );
}

export default SelectedReplicaset;
