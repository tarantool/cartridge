import { css } from '@emotion/css';
import { baseFontFamily } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    display: flex;
    flex: 1 0 auto;

    font-family: ${baseFontFamily};
    font-size: 14px;
    line-height: 22px;
    font-weight: 400;

    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
};
