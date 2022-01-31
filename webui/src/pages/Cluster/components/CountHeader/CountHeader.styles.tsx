import { css } from '@emotion/css';
import { baseFontFamily, colors } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    font-family: ${baseFontFamily};
    font-size: 14px;
    font-weight: 400;
    line-height: 22px;

    color: ${colors.dark};

    & + & {
      margin-left: 10px;
    }
  `,
  label: css``,
  counter: css`
    padding-left: 5px;
    color: ${colors.dark40};
  `,
};
