import React, { useMemo } from 'react';
import { useEvent, useStore } from 'effector-react';

import * as models from 'src/models';
import ReplicasetFilter from 'src/pages/Cluster/components/ReplicasetFilter';

import { CountHeader } from '../../../CountHeader';
import { CountHeaderDelimiter } from '../../../CountHeaderDelimiter';
import { CountHeaderWrapper } from '../../../CountHeaderWrapper';
import ReplicasetFilterInput from '../../../ReplicasetFilterInput';

import { styles } from './ReplicasetListHeader.styles';

const { $cluster, $rolesFilter, $serverList, $ratingFilter, setRolesFiltered, setRatingFiltered, selectors } =
  models.cluster.serverList;

const ReplicasetListHeader = () => {
  const serverListStore = useStore($serverList);
  const clusterStore = useStore($cluster);
  const rolesFilter = useStore($rolesFilter);
  const ratingFilter = useStore($ratingFilter);

  const setRolesFilter = useEvent(setRolesFiltered);
  const setRatingFilter = useEvent(setRatingFiltered);

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
          value={rolesFilter}
          setValue={setRolesFilter}
          roles={knownRoles}
        />
        <ReplicasetFilter
          filters={[
            { prefix: 'is', name: 'leader' },
            { prefix: 'is', name: 'followers' },
          ]}
          className="meta-test__Filter"
          value={ratingFilter}
          setValue={setRatingFilter}
        />
      </div>
    </div>
  );
};

export default ReplicasetListHeader;
