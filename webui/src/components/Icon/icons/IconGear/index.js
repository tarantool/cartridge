// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './gear.svg';

const styles = css`
  width: 12px;
  height: 12px;
  fill: #F5222D;
`;

export const IconGear = ({ className }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
  />
);
