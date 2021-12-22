import React, { useCallback, useMemo } from 'react';
/* eslint-disable @typescript-eslint/ban-ts-comment */
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';

import * as models from 'src/models';

import ReplicasetFilterInput from '../../../ReplicasetFilterInput';

import { styles } from './ReplicasetListHeader.styles';

const { $cluster, selectors, $serverList } = models.cluster.serverList;

export interface ReplicasetListHeaderProps {
  filter: string;
  onFilterChange: (value: string) => void;
}

const removeStatusFromFilter = (filter: string) =>
  filter
    .replace(/status:[^\s]+/g, '')
    .replace(/\s+/g, ' ')
    .trim();

const ReplicasetListHeader = ({ filter, onFilterChange }: ReplicasetListHeaderProps) => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const { total, healthy, unhealthy } = useMemo(() => selectors.replicasetCounts(serverListStore), [serverListStore]);
  const knownRoles = useMemo(() => selectors.knownRoles(clusterStore), [clusterStore]);

  const filterType = useMemo(() => {
    if (filter.indexOf('status:healthy') > -1) {
      return 'healthy';
    } else if (filter.indexOf('status:unhealthy') > -1) {
      return 'unhealthy';
    }
    return 'all';
  }, [filter]);

  const handleAllServersFilterClick = useCallback(() => {
    onFilterChange(removeStatusFromFilter(filter));
  }, [filter, onFilterChange]);

  const handleHealthyServersFilterClick = useCallback(() => {
    if (filter.indexOf('status:healthy') === -1) {
      onFilterChange(`${removeStatusFromFilter(filter)} status:healthy`.trim());
    }
  }, [filter, onFilterChange]);

  const handleUnhealthyServersFilterClick = useCallback(() => {
    if (filter.indexOf('status:unhealthy') === -1) {
      onFilterChange(`${removeStatusFromFilter(filter)} status:unhealthy`.trim());
    }
  }, [filter, onFilterChange]);

  return (
    <div className={styles.root} data-component="ReplicasetListHeader">
      <div className={styles.counters}>
        <div
          className={cx(styles.counter, filterType !== 'all' && styles.counterInactive)}
          onClick={handleAllServersFilterClick}
          data-type="all-servers"
          data-count={total}
        >
          All Servers<span className={styles.count}>{total}</span>
        </div>
        <div
          className={cx(styles.counter, filterType !== 'healthy' && styles.counterInactive)}
          onClick={handleHealthyServersFilterClick}
          data-type="healthy-servers"
          data-count={healthy}
        >
          Healthy<span className={styles.count}>{healthy}</span>
        </div>
        <div
          className={cx(styles.counter, filterType !== 'unhealthy' && styles.counterInactive)}
          onClick={handleUnhealthyServersFilterClick}
          data-type="unhealthy-servers"
          data-count={unhealthy}
        >
          Unhealthy<span className={styles.count}>{unhealthy}</span>
        </div>
      </div>
      <div>
        <ReplicasetFilterInput
          className={cx(styles.clusterFilter, 'meta-test__Filter')}
          value={filter}
          setValue={onFilterChange}
          roles={knownRoles}
        />
      </div>
    </div>
  );
};

export default ReplicasetListHeader;
