// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import checkbox from './checkbox.svg';
import checkboxChecked from './checkbox-checked.svg';
import checkboxDisabled from './checkbox-disabled.svg';
import checkboxCheckedDisabled from './checkbox-checked-disabled.svg';

const CHECKED = 2;
const DISABLED = 1;

const states = [
  checkbox,
  checkboxDisabled,
  checkboxChecked,
  checkboxCheckedDisabled
];

const styles = css`
  width: 16px;
  height: 16px;
`;

type IconCheckboxProps = {
  ...$Exact<GenericIconProps>,
  checked?: boolean,
  disabled?: boolean,
}

export const IconCheckbox = ({ checked, className, disabled }: IconCheckboxProps) => {
  const mask = (disabled ? DISABLED : 0) + (checked ? CHECKED : 0);
  return (
    <Icon
      className={cx(styles, className)}
      glyph={states[mask]}
    />
  );
};
