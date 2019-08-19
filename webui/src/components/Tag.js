// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';

const styles = {
  tag: css`
    position: relative;
    border: none;
    border-radius: 4px;
    padding: 1px 8px 3px;
    margin: 0 2px;
    font-size: 12px;
    line-height: 18px;
    outline: none;
    transition: 0.1s ease-in-out;
    transition-property: background-color, color;

    &:focus::before {
      content: '';
      position: absolute;
      top: -5px;
      left: -5px;
      right: -5px;
      bottom: -5px;
      border: solid 3px rgba(245, 34, 45, 0.55);
      border-radius: 6px;
    }
  `,
  interactive: (className?: string) => className
    ? css`
      .${className}:hover & {
        color: #ffffff;
        background-color: rgba(0, 0, 0, 0.65);
      }

      .${className} &:hover,
      .${className} &:focus {
        background-color: #000000;
        color: #ffffff;
      }
    `
    : '',
  static: css`
    color: #ffffff;
    background-color: rgba(0, 0, 0, 0.65);

    &:hover,
    &:focus {
      background-color: #000000;
      color: #ffffff;
    }
  `
};

export type ServerLabelsProps = {
  className?: string,
  hoverParentClassName?: string,
  highlightingOnHover?: string,
  onClick?: (MouseEvent) => void,
  text: string,
};

const ServerLabels = ({ highlightingOnHover, className, onClick, text }: ServerLabelsProps) => {
  const Element = onClick ? 'button' : 'span';

  return (
    <Element
      className={cx(
        {
          [styles.interactive(highlightingOnHover)]: highlightingOnHover,
          [styles.static]: !highlightingOnHover
        },
        styles.tag,
        className
      )}
      onClick={onClick}
    >
      {text}
    </Element>
  );
}

export default ServerLabels;
