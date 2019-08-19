// @flow
// TODO: move to uikit
// TODO: rename to Input
import * as React from 'react';
import { createRef } from 'react';
import { css, cx } from 'react-emotion';
import { IconCancel } from 'src/components/Icon';

const styles = {
  outer: css`
    position: relative;
    border: solid 1px #D9D9D9;
    box-sizing: border-box;
    border-radius: 4px;
    background-color: #ffffff;
  `,
  disabled: css`
    background-color: #F3F3F3;
  `,
  focused: css`
    border-color: rgba(0, 0, 0, 0.26);
    box-shadow: 0px 0px 3px rgba(0, 0, 0, 0.24);
  `,
  error: css`
    border-color: #F5222D;
    box-shadow: 0px 0px 3px rgba(245, 34, 45, 0.65);
  `,
  input: css`
    display: block;
    width: 100%;
    height: 100%;
    border: 0;
    padding: 5px 16px;
    box-sizing: border-box;
    border-radius: 3px;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    line-height: 22px;
    color: rgba(0, 0, 0, 0.65);
    background-color: transparent;
    outline: none;
  `,
  inputWithIcon: css`
    padding: 5px 32px 5px 16px;
  `,
  iconWrap: css`
    position: absolute;
    top: 7px;
    right: 7px;
    bottom: 7px;
    display: flex;
    align-items: center;
  `
};

type InputProps = {
  autoComplete?: 'on' | 'off',
  autoFocus?: boolean,
  className?: string,
  onClearClick?: (e: MouseEvent) => void,
  disabled?: boolean,
  error?: boolean,
  name?: string,
  onBlur?: (e: MouseEvent) => void,
  onChange?: (e: InputEvent) => void,
  onFocus?: (e: MouseEvent) => void,
  readOnly?: boolean,
  rightIcon?: React.Node,
  type?: 'text' | 'password' | 'email',
  value?: string,
  placeholder?: string
};

type InputState = {
  focused: boolean;
};

export default class InputText extends React.Component<InputProps, InputState> {
  inputRef = createRef();

  state = {
    focused: false
  };

  render() {
    const {
      autoComplete,
      autoFocus,
      className,
      onClearClick,
      disabled,
      error,
      name,
      onBlur,
      onChange,
      onFocus,
      readOnly,
      rightIcon,
      type,
      value,
      placeholder
    } = this.props;

    const { focused } = this.state;

    return (
      <div
        className={cx(
          styles.outer,
          {
            [styles.disabled]: disabled,
            [styles.focused]: focused,
            [styles.error]: error
          },
          className
        )}
      >
        <input
          autoFocus={autoFocus}
          autoComplete={autoComplete}
          className={cx(styles.input, { [styles.inputWithIcon]: rightIcon || onClearClick })}
          disabled={disabled}
          name={name}
          onChange={onChange}
          onBlur={this.handleInputBlur}
          onFocus={this.handleInputFocus}
          type={type}
          value={value}
          placeholder={placeholder}
          readOnly={readOnly}
          ref={this.inputRef}
        />
        {(onClearClick || rightIcon) && (
          <div className={styles.iconWrap}>
            {onClearClick && (!rightIcon || value)
              ? <IconCancel onClick={!(disabled || readOnly) && this.handleClearClick} />
              : rightIcon}
          </div>
        )}
      </div>
    );
  }

  handleInputFocus = () => this.setState({ focused: true });

  handleInputBlur = (e: Object) => {
    this.setState({ focused: false });
    this.props.onBlur && this.props.onBlur(e);
  };

  handleClearClick = () => {
    this.inputRef.current.focus();
    this.props.onClearClick();
  }
}
