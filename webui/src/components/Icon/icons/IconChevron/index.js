// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import Icon, { type GenericIconProps } from '../../Icon';
import image from './chevron-up.svg';

const styles = {
  down: css`
    transform: rotate(180deg);
  `
};

type IconChevronProps = {
  ...$Exact<GenericIconProps>,
  direction: 'top' | 'bottom';
}

export const IconChevron = (props: IconChevronProps) => {
  const { direction, ...otherProps } = props;

  return (
    <Icon
      className={cx({
        [styles.down]: direction === 'bottom'
      })}
      glyph={image}
      hasState={true}
      {...otherProps}
    />
  );
};
