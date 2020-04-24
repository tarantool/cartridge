// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import {
  Button,
  NonIdealStateAction,
  splashGenericErrorSvg
} from '@tarantool.io/ui-kit';

const styles = {
  block: css`
    height: calc(100% - 69px);
  `,
  icon: css`
    width: 80px;
    height: 80px;
    margin-bottom: 24px;
  `,
};

type SectionLoadErrorProps = {
  className?: string,
  onClick: () => void
};

const IconGenericError = () => (
  <svg
    viewBox={splashGenericErrorSvg.viewBox}
    className={styles.icon}
  >
    <use xlinkHref={`#${splashGenericErrorSvg.id}`}/>
  </svg>
);

export const SectionLoadError = ({ className, onClick }: SectionLoadErrorProps) => (
  <NonIdealStateAction
    className={cx(styles.block, className)}
    icon={IconGenericError}
    title='Error loading component'
    actionText='Retry'
    onActionClick={onClick}
  />
);
