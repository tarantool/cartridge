import React, { useMemo } from 'react';
import { useStore } from 'effector-react';

import * as models from 'src/models';

import { CountHeader } from '../../../CountHeader';
import { CountHeaderDelimiter } from '../../../CountHeaderDelimiter';
import { CountHeaderWrapper } from '../../../CountHeaderWrapper';
import ReplicasetFilterInput from '../../../ReplicasetFilterInput';

import { styles } from './ReplicasetListHeader.styles';

const { $cluster, selectors, $serverList } = models.cluster.serverList;

export interface ReplicasetListHeaderProps {
  filter: string;
  onFilterChange: (value: string) => void;
}

const ReplicasetListHeader = ({ filter, onFilterChange }: ReplicasetListHeaderProps) => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);

  const { total, unhealthy } = useMemo(() => selectors.replicasetCounts(serverListStore), [serverListStore]);
  const knownRoles = useMemo(() => selectors.knownRoles(clusterStore), [clusterStore]);

  return (
    <div className={styles.root} data-component="ReplicasetListHeader">
      <CountHeaderWrapper className={styles.counters}>
        <CountHeader data-type="total-replicasets" counter={total.replicasets} />
        <CountHeader data-type="unhealthy-replicasets" counter={unhealthy.replicasets} />
        <CountHeaderDelimiter />
        <CountHeader data-type="total-instances" counter={total.instances} />
        <CountHeader data-type="unhealthy-instances" counter={unhealthy.instances} />
      </CountHeaderWrapper>
      <div className={styles.d} />
      <div className={styles.filter}>
        <ReplicasetFilterInput
          className="meta-test__Filter"
          value={filter}
          setValue={onFilterChange}
          roles={knownRoles}
        />
      </div>
    </div>
  );
};

export default ReplicasetListHeader;
