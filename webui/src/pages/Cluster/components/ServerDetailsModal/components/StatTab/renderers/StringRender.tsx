import React from 'react';
import { Text } from '@tarantool.io/ui-kit';

import { styles } from '../StatTab.styles';

export interface StringRenderProps {
  value: unknown;
}

export const StringRender = ({ value }: StringRenderProps) => {
  let checkValue = '';
  if (Array.isArray(value)) {
    checkValue = `[${value.join(', ')}]`;
  } else if (typeof value === 'string') {
    checkValue = value;
  } else {
    checkValue = JSON.stringify(value);
  }
  return (
    <div className={styles.rightCol}>
      <Text variant="basic">{checkValue}</Text>
    </div>
  );
};
