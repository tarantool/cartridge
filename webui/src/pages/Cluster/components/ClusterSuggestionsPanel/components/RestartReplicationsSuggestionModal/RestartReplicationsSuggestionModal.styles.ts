import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  msg: css`
    margin-bottom: 20px;
    white-space: pre-line;
  `,
  list: css`
    list-style: none;
    padding-left: 0;
    color: ${colors.dark65};
  `,
  listItem: css`
    margin-bottom: 11px;

    &:last-child {
      margin-bottom: 0;
    }
  `,
};
