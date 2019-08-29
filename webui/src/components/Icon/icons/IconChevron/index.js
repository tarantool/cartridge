// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './chevron-up.svg';

const styles = {
  icon: css`
    fill: #ffffff;
  `,
  down: css`
    transform: rotate(180deg);
  `
};

type IconChevronProps = {
  ...$Exact<GenericIconProps>,
  direction: 'up' | 'down';
}

export const IconChevron = (props: IconChevronProps) => {
  const { direction, className, ...otherProps } = props;

  return (
    <Icon
      className={cx(
        styles.icon,
        { [styles.down]: direction === 'down' },
        className
      )}
      glyph={image}
      hasState={true}
      {...otherProps}
    />
  );
};
