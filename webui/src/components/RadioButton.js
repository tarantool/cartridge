// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import { IconRadio } from 'src/components/Icon';
import Text from 'src/components/Text';

const styles = {
  icon: css`
    display: block;
  `,
  iconWrap: css`
    position: relative;
  `,
  children: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  childrenMargin: css`
    margin-right: 8px;
  `,
  input: css`
    position: absolute;
    clip: rect(0 0 0 0);
    width: 1px;
    height: 1px;
    margin: -1px;

    &:focus + div::before {
      content: '';
      position: absolute;
      top: -5px;
      left: -5px;
      right: -5px;
      bottom: -5px;
      border: solid 3px rgba(245, 34, 45, 0.55);
      border-radius: 50%;
    }
  `,
  label: css`
    display: flex;
    align-items: center;
  `
};

type RadioButtonProps = {
  checked?: boolean,
  children?: React.Node,
  className?: string,
  disabled?: boolean,
  name?: string,
  value?: string,
  onChange?: (MouseEvent) => void
};

const RadioButton = ({
  checked,
  children,
  className,
  disabled,
  onChange,
  name,
  value
}:
RadioButtonProps) => (
  <label className={cx(styles.label, className)}>
    <input
      checked={checked}
      className={styles.input}
      disabled={disabled}
      type='radio'
      onChange={onChange}
      name={name}
      value={value}
    />
    <div
      className={cx(
        styles.iconWrap,
        { [styles.childrenMargin]: children }
      )}
    >
      <IconRadio
        className={styles.icon}
        checked={checked}
        disabled={disabled}
      />
    </div>
    {typeof children === 'string' ? <Text className={styles.children}>{children}</Text> : children}
  </label>
);

export default RadioButton;
