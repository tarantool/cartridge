import React, { useCallback, useMemo } from 'react';
import { useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { $cluster, $serverList, selectors, $bootstrapPanel, requestBootstrapEvent, showBootstrapPanelEvent } =
  cluster.serverList;

const BootstrapButton = () => {
  const clusterStore = useStore($cluster);
  const serverListStore = useStore($serverList);
  const { pending } = useStore($bootstrapPanel);

  const canBootstrapVshard = useMemo(
    () => selectors.canBootstrapVshard(serverListStore, clusterStore),
    [serverListStore, clusterStore]
  );

  const handleClick = useCallback(
    () => (canBootstrapVshard ? requestBootstrapEvent() : showBootstrapPanelEvent()),
    [canBootstrapVshard]
  );

  return (
    <Button
      className="meta-test__BootstrapButton"
      disabled={pending}
      intent="primary"
      text="Bootstrap vshard"
      onClick={handleClick}
      size="l"
    />
  );
};

export default BootstrapButton;
