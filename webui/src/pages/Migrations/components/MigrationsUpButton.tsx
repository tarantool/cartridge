import React from 'react';
import { useEvent, useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { migrations } from 'src/models';

export const MigrationsUpButton = React.memo(() => {
  const pending = useStore(migrations.$upMigrationsPending);
  const onClick = useEvent(migrations.upMigrationsEvent);
  return (
    <Button type="button" onClick={onClick} size="l" disabled={pending} loading={pending}>
      Migrations Up
    </Button>
  );
});
