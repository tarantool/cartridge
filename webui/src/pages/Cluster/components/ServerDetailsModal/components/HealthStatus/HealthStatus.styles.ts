import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  status: css`
    display: flex;
    align-items: baseline;
    flex-basis: 153px;
    color: rgba(0, 0, 0, 0.65);
  `,
};

export const states = {
  bad: css`
    color: ${colors.intentDanger};
  `,
  good: css`
    color: ${colors.dark65};
  `,
  middle: css`
    color: ${colors.intentWarningAccent};
  `,
};
