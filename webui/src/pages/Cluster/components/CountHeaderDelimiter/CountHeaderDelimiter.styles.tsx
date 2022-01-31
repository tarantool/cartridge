import { css } from '@emotion/css';
import { baseFontFamily, colors } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    font-family: ${baseFontFamily};
    font-size: 14px;
    line-height: 22px;
    font-weight: 400;

    color: ${colors.dark15};
    margin: 0 10px;
  `,
};
