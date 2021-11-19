import React, { memo, useCallback, useMemo } from 'react';
import { useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { failoverModalOpenEvent } = cluster.failover;
const { selectors, $cluster } = cluster.serverList;

const FailoverButton = () => {
  const clusterStore = useStore($cluster);

  const handleClick = useCallback(() => {
    failoverModalOpenEvent();
  }, []);

  const mode = useMemo(() => selectors.failoverParamsMode(clusterStore), [clusterStore]);

  if (!selectors.isConfigured(clusterStore)) {
    return null;
  }

  return (
    <Button className="meta-test__FailoverButton" onClick={handleClick} size="l">
      {`Failover: ${mode}`}
    </Button>
  );
};

export default memo(FailoverButton);
