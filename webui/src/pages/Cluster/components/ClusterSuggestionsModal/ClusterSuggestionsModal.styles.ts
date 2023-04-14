import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  btn: css`
    background: ${colors.intentDanger};
    color: ${colors.intentBaseActive};
    &:hover {
      background: ${colors.intentDanger};
    }
  `,

  content: css`
    padding: 0;
  `,
  suggestion: css`
    padding-bottom: 10px;
    margin-bottom: 10px;
    border-bottom: 1px solid ${colors.intentBase};
  `,
};
