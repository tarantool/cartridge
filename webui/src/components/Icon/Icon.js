// @flow
// TODO: move to uikit
import * as React from 'react'
import { css, cx } from 'emotion';
// import { iconSize } from '../../variables';
const iconSize = '14px';

const styles = {
  icon: css`
    vertical-align: middle;
    width: ${iconSize};
    height: ${iconSize};
  `,
  state: css`
    fill: red;

    &:hover {
      fill: greenyellow;
    }

    &.active {
      fill: blue;
    }
  `,
  stroke: css`
    stroke: red;

    &:hover {
      fill: greenyellow;
    }

    &.active {
      fill: blue;
    }
  `,
  clickable: css`
    cursor: pointer;
  `,
  active: css``,
  button: css`
    display: block;
    padding: 0;
    border: none;
    outline: none;
    background: transparent;

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
  `
};

type Glyph = {
  content: string,
  id: string,
  node: any,
  viewBox: string,
};

type IconProps = {
  active?: boolean; // Выбраное состояние
  className?: string;
  glyph: Glyph,
  hasState?: boolean, // Включение состояния: Normal, Hover, Active
  onClick?: (evt: MouseEvent) => void,
  onMouseEnter?: () => void,
  onMouseLeave?: () => void,
  stroke?: boolean // Задавать stroke вместо fill
};

export type GenericIconProps = {
  className?: string,
  onClick?: (e: MouseEvent) => void
};


const Icon = ({
  active,
  className,
  glyph,
  hasState,
  onMouseLeave,
  onMouseEnter,
  onClick,
  stroke
}:
IconProps) => {
  const isInteractive = onClick || onMouseEnter || onMouseLeave;

  return (
    <svg
      viewBox={glyph.viewBox}
      onClick={onClick}
      onMouseLeave={onMouseLeave}
      onMouseEnter={onMouseEnter}
      className={cx(
        styles.icon,
        className,
        {
          [styles.stroke]: stroke,
          [styles.clickable]: !!onClick,
          [styles.active]: active
        }
      )}
    >
      <use xlinkHref={`#${glyph.id}`}/>
    </svg>
  );
};

export default Icon;
