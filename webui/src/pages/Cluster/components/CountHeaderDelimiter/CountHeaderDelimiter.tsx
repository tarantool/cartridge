import React, { memo } from 'react';

import { styles } from './CountHeaderDelimiter.styles';

export const CountHeaderDelimiter = memo(() => {
  return (
    <span className={styles.root} data-component="CountHeaderDelimiter">
      |
    </span>
  );
});
