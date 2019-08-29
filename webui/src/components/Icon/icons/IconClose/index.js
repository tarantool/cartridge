// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './close.svg';

const styles = css`
  width: 16px;
  height: 16px;
`;

export const IconClose = ({ className, onClick }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
    onClick={onClick}
  />
);
