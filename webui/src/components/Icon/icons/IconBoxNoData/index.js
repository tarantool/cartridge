// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './empty-box-no-data.svg';

const styles = css`
  width: 64px;
  height: 41px;
`;

export const IconBoxNoData = ({ className }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
  />
);
