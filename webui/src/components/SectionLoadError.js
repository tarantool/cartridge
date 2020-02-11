// @flow
import * as React from 'react';
import { css, cx } from 'emotion';
import {
  Button,
  IconCancel,
  NonIdealStateAction
} from '@tarantool.io/ui-kit';

const style = css`
  height: calc(100% - 69px);
`;

type SectionLoadErrorProps = {
  className?: string,
  onClick: () => void
};

export const SectionLoadError = ({ className, onClick }: SectionLoadErrorProps) => (
  <NonIdealStateAction
    className={cx(style, className)}
    icon={IconCancel}
    title='Error loading component'
    actionText='Retry'
    onActionClick={onClick}
  />
);
