import React from 'react';
import { Text } from '@tarantool.io/ui-kit';

import { styles } from '../StatTab.styles';

export interface BooleanRenderProps {
  value: unknown;
}

export const BooleanRender = ({ value }: BooleanRenderProps) => (
  <div className={styles.rightCol}>
    <Text variant="basic">{`${value ?? ''}`}</Text>
  </div>
);
