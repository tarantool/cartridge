import React from 'react';
import { Text } from '@tarantool.io/ui-kit';

import { styles } from '../StatTab.styles';

export interface StringRenderProps {
  value: unknown;
}

export const StringRender = ({ value }: StringRenderProps) => (
  <div className={styles.rightCol}>
    <Text variant="basic">{Array.isArray(value) ? `[${value.join(', ')}]` : `${value ?? ''}`}</Text>
  </div>
);
