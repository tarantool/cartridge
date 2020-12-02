// @flow

import * as React from 'react'
import { css, cx } from 'emotion';
import {
  SVGImage,
  Text,
  colors
} from '@tarantool.io/ui-kit';
import crownPicture from './crown-gray.svg';

const styles = {
  label: css`
    display: inline-block;
    padding: 1px 9px 1px 10px;
    font-size: 11px;
    line-height: 17px;
    color: ${colors.dark65};
    text-transform: uppercase;
  `,
  img: css`margin-right: 4px;`
};

const intentions = {
  good: css`background-color: ${colors.intentSuccessBorder};`,
  bad: css`background-color: ${colors.intentDanger};`,
  warning: css`background-color: ${colors.intentWarningAccent};`
};

type LeaderLabelProps = {
  className?: string,
  state: 'warning' | 'good' | 'bad'
};

export const LeaderLabel = ({ className, state = 'bad' }: LeaderLabelProps) => (
  <Text variant='h5' tag='span' className={cx(styles.label, intentions[state], className)}>
    <SVGImage glyph={crownPicture} className={styles.img} />
    Leader
  </Text>
);
