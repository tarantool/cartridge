// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import { Icon, type GenericIconProps } from '@tarantool.io/ui-kit';
import image from './glyph.svg';

const styles = css`
  width: 12px;
  height: 12px;
`;

export const IconFileWithCode = ({ className, onClick }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
    onClick={onClick}
  />
);
