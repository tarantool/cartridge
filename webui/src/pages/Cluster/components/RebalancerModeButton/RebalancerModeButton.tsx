import React, { memo, useCallback, useMemo } from 'react';
import { useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { rebalancerModeModalOpenEvent } = cluster.replicasetModeConfigure;
const { selectors, $cluster } = cluster.serverList;

const RebalancerModeButton = () => {
  const clusterStore = useStore($cluster);

  const data = useMemo(() => selectors.rebalancerMode(clusterStore), [clusterStore]);

  const handleClick = useCallback(() => {
    if (data) {
      rebalancerModeModalOpenEvent(data);
    }
  }, [data]);

  if (!(selectors.isConfigured(clusterStore) && selectors.isVshardAvailable(clusterStore) && data)) {
    return null;
  }

  return (
    <Button className="meta-test__RebalancerModeButton" onClick={handleClick} size="l">
      {`Rebalancer mode: ${data.rebalancer_mode}`}
    </Button>
  );
};

export default memo(RebalancerModeButton);
