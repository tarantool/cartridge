import React, { memo, useMemo } from 'react';
import { cx } from '@emotion/css';

import { cluster } from 'src/models';
import type { ServerListReplicasetSearchable } from 'src/models';

import ReplicasetListTag from '../ReplicasetListTag';

import { styles } from './CrudSafeModeTag.styles';

const { selectors } = cluster.serverList;

export type CrudSafeModeTagProps = {
  enabledCount?: number;
  totalCount?: number;
  className?: string;
};

export const CrudSafeModeTag = memo(({ enabledCount, totalCount, className }: CrudSafeModeTagProps) => {
  const partial = enabledCount !== undefined && totalCount !== undefined && enabledCount < totalCount;
  return (
    <ReplicasetListTag
      className={cx(styles.root, className, 'meta-test__crudSafeMode')}
      title="CRUD safe mode is enabled: writes are slower. Disable it after rebalancing is finished."
    >
      {partial ? `safe mode ${enabledCount}/${totalCount}` : 'safe mode'}
    </ReplicasetListTag>
  );
});

export type ReplicasetCrudSafeModeTagProps = {
  replicaset: ServerListReplicasetSearchable;
  className?: string;
};

export const ReplicasetCrudSafeModeTag = memo(({ replicaset, className }: ReplicasetCrudSafeModeTagProps) => {
  const { enabledCount, totalCount } = useMemo(() => selectors.replicasetCrudSafeMode(replicaset), [replicaset]);
  if (enabledCount === 0) {
    return null;
  }
  return <CrudSafeModeTag enabledCount={enabledCount} totalCount={totalCount} className={className} />;
});
