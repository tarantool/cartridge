// @flow
// TODO: move to uikit
import * as React from 'react'
import { css, cx } from 'react-emotion'

const styles = {
  button: css`
    border: solid 1px;
    border-radius: 4px;
    box-sizing: border-box;
    font-family: 'Open Sans', sans-serif;
    font-size: 14px;
    line-height: 22px;
    transition: 0.07s ease-in-out;
    outline: none;
    cursor: pointer;
    -webkit-font-smoothing: antialiased;

    &:disabled,
    &:disabled:active,
    &:disabled:hover {
      border-color: #d9d9d9;
      color: #bfbfbf;
      background-color: #f3f3f3;
      box-shadow: none;
      cursor: default;
    }

    &:disabled svg {
      filter: grayscale(1) brightness(1.5);
    }
  `,

  base: css`
    border-color: #d9d9d9;
    background-color: transparent;
    color: rgba(0, 0, 0, 0.65);

    &:focus,
    &:hover {
      box-shadow: 0px 10px 15px rgba(0, 0, 0, 0.05);
    }

    &:active {
      border-color: rgba(217, 217, 217, 0.45);
      background-color: #fafafa;
      color: rgba(0, 0, 0, 0.65);
      box-shadow: none;
    }
  `,

  icon: css`
    margin-bottom: 2px;
  `,

  iconMargin: css`
    margin-right: 8px;
  `,

  primary: css`
    border-color: #f5222d;
    background-color: #f5222d;
    color: #ffffff;

    &:focus,
    &:hover {
      box-shadow: 0px 10px 15px rgba(245, 34, 45, 0.15);
    }

    &:active {
      border-color: #cf1322;
      background-color: #cf1322;
      box-shadow: none;
    }
  `,

  secondary: css`
    border-color: rgba(245, 34, 45, 0.25);
    background-color: transparent;
    color: rgba(245, 34, 45, 0.65);

    &:focus,
    &:hover {
      border-color: #f5222d;
      color: #f5222d;
      box-shadow: 0px 10px 15px rgba(245, 34, 45, 0.15);
    }

    &:active {
      border-color: #cf1322;
      color: #cf1322;
      box-shadow: none;
    }
  `,

  iconic: css`
    border-color: transparent;
    background-color: transparent;
    color: rgba(245, 34, 45, 0.65);

    &:focus,
    &:hover {
      border-color: rgba(217, 217, 217, 0.45);
      color: #f5222d;
      box-shadow: 0px 10px 15px rgba(245, 34, 45, 0.15);
    }

    &:active {
      border-color: #fafafa;
      background-color: #fafafa;
      color: #cf1322;
      box-shadow: none;
    }
  `,

  m: css`
    padding: 4px 15px;
  `,

  s: css`
    padding: 0px 15px;
  `,

  iconicM: css`
    padding: 4px 7px;
  `,

  iconicS: css`
    padding: 0px 3px;
  `
};

type ButtonProps = {
  className?: string,
  children?: React.Node,
  disabled?: boolean,
  icon?: React.Component<any>,
  intent?: 'primary' | 'secondary' | 'base',
  onClick?: (MouseEvent) => void,
  size?: 's' | 'm',
  text?: string,
  type?: 'button' | 'submit'
};

export default ({
  className,
  children,
  disabled,
  icon: Icon,
  intent = 'base',
  onClick,
  size = 'm',
  text,
  type = 'button'
}:
ButtonProps) => {
  const isOnlyIcon = Icon && !children && !text;

  return (
    <button
      className={cx(
        styles.button,
        styles[intent],
        {
          [styles.iconicM]: isOnlyIcon && size === 'm',
          [styles.iconicS]: isOnlyIcon && size === 's',
          [styles.m]: !isOnlyIcon && size === 'm',
          [styles.s]: !isOnlyIcon && size === 's'
        },
        className
      )}
      disabled={disabled}
      onClick={onClick}
      type={type}
    >
      {Icon && (
        <Icon
          className={cx(
            styles.icon,
            {
              [styles.iconMargin]: !isOnlyIcon
            }
          )}
        />
      )}
      {children || text}
    </button>
  );
}
