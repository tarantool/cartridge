// @flow
import React from 'react';
import { css, cx } from '@emotion/css';
import { rgba } from 'emotion-rgba';
import { colors } from '@tarantool.io/ui-kit';

import { Label } from '../Label';

const styles = {
  img: css`
    margin-right: 4px;
    fill: ${colors.dark65};
  `,
  imgLight: css`
    fill: #fff;
    fill-opacity: 0.65;
  `,
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
  `,
};

type Props = {
  className?: string,
  state: 'warning' | 'good' | 'bad',
};

export const LeaderLabel = ({ className, state = 'bad' }: Props) => (
  <Label variant="h5" tag="span" className={cx(intentions[state], className)}>
    <svg
      width="8"
      height="8"
      xmlns="http://www.w3.org/2000/svg"
      className={cx(styles.img, { [styles.imgLight]: state === 'bad' })}
    >
      <path d="M.889 5.867L0 0l2.444 3.733L4 0l1.556 3.733L8 0l-.889 5.867H.89zm6.222 1.6c0 .294-.199.533-.444.533H1.333C1.088 8 .89 7.761.89 7.467v-.534H7.11v.534z" />
    </svg>
    Leader
  </Label>
);
