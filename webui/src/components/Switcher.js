// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import Text from 'src/components/Text';

const styles = {
  input: css`
    position: absolute;
    clip: rect(0 0 0 0);
    width: 1px;
    height: 1px;
    margin: -1px;

    &:focus + div::before {
      content: '';
      position: absolute;
      top: -3px;
      left: -3px;
      right: -3px;
      bottom: -3px;
      border: solid 1px rgba(245, 34, 45, 0.55);
      border-radius: 15px;
    }
  `,
  switcher: css`
    position: relative;
    flex-shrink: 0;
    width: 42px;
    height: 22px;
    border: solid 1px transparent;
    border-radius: 12px;
    margin-right: 8px;
    box-sizing: border-box;
    background-color: #a6a6a6;
    cursor: pointer;

    &::after {
      content: '';
      position: absolute;
      top: 1px;
      left: 1px;
      width: 18px;
      height: 18px;
      border-radius: 50%;
      background-color: #ffffff;
    }
  `,
  children: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  childrenMargin: css`
    margin-right: 8px;
  `,
  basicDisabled: css`
    cursor: default;
  `,
  notDisabled: css`
    background-color: rgba(0,0,0,0.25);

    &:hover,
    &:focus {
      background-color: rgba(0,0,0,0.35);
    }
  `,
  checked: css`
    background-color: #f5222d;

    &:hover,
    &:focus {
      background-color: #CF1322;
    }

    &::after {
      left: auto;
      right: 1px;
    }
  `,
  disabled: css`
    border-color: #d9d9d9;
    background-color: #f3f3f3;
    cursor: default;

    &::after {
      box-shadow: 0px 0px 4px rgba(0, 0, 0, 0.15);
    }
  `,
  checkedDisabled: css`
    background-color: #fcc8cb;

    &::after {
      left: auto;
      right: 1px;
    }
  `,
  label: css`
    display: flex;
    align-items: center;
  `
};

type SwitcherProps = {
  checked?: boolean,
  children?: React.Node,
  className?: string,
  disabled?: boolean,
  onChange?: (MouseEvent) => void
};

const Switcher = ({
  checked,
  children,
  className,
  disabled,
  onChange
}:
SwitcherProps) => (
  <label className={cx(styles.label, className)}>
    <input
      checked={checked}
      className={styles.input}
      disabled={disabled}
      type='checkbox'
      onChange={onChange}
    />
    <div
      className={cx(
        styles.switcher,
        {
          [styles.notDisabled]: !checked && !disabled,
          [styles.checked]: checked && !disabled,
          [styles.disabled]: !checked && disabled,
          [styles.basicDisabled]: disabled,
          [styles.checkedDisabled]: checked && disabled,
          [styles.childrenMargin]: children
        }
      )}
    />
    {typeof children === 'string' ? <Text className={styles.children}>{children}</Text> : children}
  </label>
);

export default Switcher;
