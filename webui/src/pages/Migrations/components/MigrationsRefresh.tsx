import React from 'react';
import { useEvent, useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { migrations } from 'src/models';

export const MigrationsRefresh = React.memo(() => {
  const pending = useStore(migrations.$requestMigrationsStatePending);
  const onClick = useEvent(migrations.requestMigrationsStateEvent);
  return (
    <Button type="button" onClick={onClick} size="l" disabled={pending} loading={pending}>
      Refresh
    </Button>
  );
});
