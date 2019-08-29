// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import Text from 'src/components/Text';
import { Field } from 'formik';
import { IconCheckbox } from './Icon/icons/IconCheckbox';

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
      top: -2px;
      left: -2px;
      right: -2px;
      bottom: -2px;
      border: solid 1px rgba(245, 34, 45, 0.55);
      border-radius: 3px;
    }
  `,
  label: css`
    display: flex;
    align-items: center;
    cursor: pointer;
  `
};

type CheckboxProps = {
  checked?: boolean,
  children?: React.Node,
  className?: string,
  disabled?: boolean,
  name?: string,
  value?: string,
  onChange?: (MouseEvent) => void
};

const Checkbox = ({
  checked,
  children,
  className,
  disabled,
  onChange,
  name,
  value
}:
CheckboxProps) => (
  <label className={cx(styles.label, className)}>
    <input
      checked={checked}
      className={styles.input}
      disabled={disabled}
      type='checkbox'
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
      <IconCheckbox
        className={styles.icon}
        checked={checked}
        disabled={disabled}
      />
    </div>
    {typeof children === 'string' ? <Text>{children}</Text> : children}
  </label>
);

export default Checkbox;

export const CheckboxField = props => (
  <Field name={props.name}>
    {({ field, form }) => (
      <Checkbox
        {...props}
        checked={field.value && field.value.includes(props.value)}
        onChange={() => {
          if (field.value && field.value.includes(props.value)) {
            const nextValue = field.value.filter(
              value => value !== props.value
            );
            form.setFieldValue(props.name, nextValue);
          } else {
            const nextValue = field.value.concat(props.value);
            form.setFieldValue(props.name, nextValue);
          }
        }}
      >
        {props.children || props.value}
      </Checkbox>
    )}
  </Field>
);
