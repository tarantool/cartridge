import React from 'react';
import { useEvent, useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { migrations } from 'src/models';

export const MigrationsMoveButton = React.memo(() => {
  const pending = useStore(migrations.$moveMigrationsPending);
  const onClick = useEvent(migrations.moveMigrationsEvent);
  return (
    <Button type="button" onClick={onClick} size="l" disabled={pending} loading={pending}>
      Move migrations state
    </Button>
  );
});
