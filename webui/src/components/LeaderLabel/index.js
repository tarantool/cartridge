// @flow

import * as React from 'react'
import { css, cx } from 'emotion';
import { rgba } from 'emotion-rgba';
import {
  SVGImage,
  colors
} from '@tarantool.io/ui-kit';
import { Label } from '../Label';
import crownPicture from './crown-gray.svg';

const styles = {
  img: css`
    margin-right: 4px;
    fill: ${colors.dark65};
  `,
  imgLight: css`
    fill: #fff;
    fill-opacity: 0.65;
  `
};

const intentions = {
  good: css`
    background-color: ${colors.intentSuccessBorder};
  `,
  bad: css`
    background-color: ${colors.intentWarningAccent};
    color: ${rgba('#fff', 0.65)};
  `,
  warning: css`
    background-color: ${colors.intentWarning};
  `
};

type Props = {
  className?: string,
  state: 'warning' | 'good' | 'bad'
};

export const LeaderLabel = ({ className, state = 'bad' }: Props) => (
  <Label variant='h5' tag='span' className={cx(intentions[state], className)}>
    <SVGImage
      glyph={crownPicture}
      className={cx(
        styles.img,
        { [styles.imgLight]: state === 'bad' }
      )}
    />
    Leader
  </Label>
);
