import { css } from '@emotion/css';
import { baseFontFamily, colors } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    padding: 0 8px;
    text-transform: uppercase;
    border-radius: 4px;
    white-space: nowrap;
    overflow: hidden;

    cursor: auto;
    background-color: ${colors.dark10};
    color: ${colors.dark65};

    font-family: ${baseFontFamily};
    font-weight: 600;
    font-size: 11px;
    line-height: 22px;
    letter-spacing: 0.01em;

    & + & {
      margin-left: 8px;
    }
  `,
};
