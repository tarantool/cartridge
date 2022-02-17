/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { css, cx } from '@emotion/css';
// @ts-ignore
import { GenericIconProps, IconOk } from '@tarantool.io/ui-kit';

const styles = {
  contrastIcon: css`
    fill: gray;
  `,
};

const IconOkContrast = ({ className, ...props }: GenericIconProps) => (
  <IconOk className={cx(styles.contrastIcon, className)} {...props} />
);

export default memo(IconOkContrast);
