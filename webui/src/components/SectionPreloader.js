// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import { IconSpinner, NonIdealState } from '@tarantool.io/ui-kit';

const style = css`
  height: calc(100% - 69px);
`;

type SectionPreloaderProps = { className?: string };

export const SectionPreloader = ({ className }: SectionPreloaderProps) => (
  <NonIdealState
    className={cx(style, className)}
    icon={IconSpinner}
    title='Loading...'
  />
);
