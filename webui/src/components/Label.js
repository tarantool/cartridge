// @flow

import * as React from 'react'
import { css, cx } from 'emotion';
import {
  Text,
  colors
} from '@tarantool.io/ui-kit';

const styles = {
  label: css`
    display: inline-block;
    padding: 1px 9px 1px 10px;
    font-size: 11px;
    line-height: 17px;
    color: ${colors.dark65};
    background-color: ${colors.intentBase};
    text-transform: uppercase;
  `
};

type Props = {
  className?: string,
  children?: React.Node
};

export const Label = ({ className, children }: Props) => (
  <Text variant='h5' tag='span' className={cx(styles.label, className)}>
    {children}
  </Text>
);
