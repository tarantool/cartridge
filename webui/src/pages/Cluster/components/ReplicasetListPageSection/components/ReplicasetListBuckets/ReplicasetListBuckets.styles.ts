import { css } from '@emotion/css';
import { baseFontFamily } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
  `,
  icon: css`
    margin-right: 5px;
  `,
  label: css`
    font-family: ${baseFontFamily};
    font-size: 12px;
    line-height: 20px;

    overflow: hidden;
    text-overflow: ellipsis;
  `,
};
