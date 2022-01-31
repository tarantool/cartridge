import React, { ReactNode } from 'react';
import { cx } from '@emotion/css';

import { styles } from './CountHeaderWrapper.styles';

export interface CountHeaderWrapperProps {
  children: ReactNode;
  className?: string;
}

export const CountHeaderWrapper = ({ children, className }: CountHeaderWrapperProps) => {
  return <div className={cx(styles.root, className)}>{children}</div>;
};
