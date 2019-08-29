// @flow
// TODO: delete?
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './crown.svg';

const styles = css`
  width: 8px;
  height: 8px;
`;

export const IconCrown = ({ className }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
  />
);