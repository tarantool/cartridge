import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  content: css`
    padding: 0;
  `,
  suggestion: css`
    padding-bottom: 10px;
    margin-bottom: 10px;
    border-bottom: 1px solid ${colors.intentBase};
  `,
};
