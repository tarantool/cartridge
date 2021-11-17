import React, { memo } from 'react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { serverProbeModalOpenEvent } = cluster.serverProbe;

const ProbeServerButton = () => {
  return (
    <Button
      className="meta-test__ProbeServerBtn"
      onClick={() => serverProbeModalOpenEvent()}
      text="Probe server"
      size="l"
    />
  );
};

export default memo(ProbeServerButton);
