import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  list: css`
    padding: 0;
  `,
  title: css`
    color: ${colors.dark40};
  `,
  suggestionContent: css`
    padding-bottom: 10px;
    margin-bottom: 10px;
    border-bottom: 1px solid ${colors.intentBase};
  `,
};
