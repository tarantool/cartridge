// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import radio from './radio.svg';
import radioSelected from './radio-checked.svg';
import radioDisabled from './radio-disabled.svg';
import radioSelectedDisabled from './radio-checked-disabled.svg';

const CHECKED = 1;
const DISABLED = 2;

const states = [
  radio,
  radioSelected,
  radioDisabled,
  radioSelectedDisabled
];

const styles = css`
  width: 16px;
  height: 16px;
`;

type IconRadioProps = {
  ...$Exact<GenericIconProps>,
  checked?: boolean,
  disabled?: boolean,
}

export const IconRadio = ({ checked, className, disabled }: IconRadioProps) => {
  const mask = (disabled ? DISABLED : 0) + (checked ? CHECKED : 0);
  return (
    <Icon
      className={cx(styles, className)}
      glyph={states[mask]}
    />
  );
};
