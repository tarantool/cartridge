// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './userpic.svg';

const styles = css`
  width: 24px;
  height: 24px;
`;

export const IconUser = ({ className, ...props }: GenericIconProps) => (
  <Icon
    className={cx(styles, className)}
    glyph={image}
    {...props}
  />
);
