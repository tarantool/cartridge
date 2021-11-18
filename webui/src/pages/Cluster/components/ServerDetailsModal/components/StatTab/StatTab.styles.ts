import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  wrap: css`
    padding: 0;
  `,
  listItem: css`
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    padding: 8px 20px;

    &:nth-child(2n) {
      background-color: #fafafa;
    }
  `,
  leftCol: css`
    display: flex;
    flex-direction: column;
    max-width: 50%;
  `,
  rightCol: css`
    max-width: 50%;
  `,
  subColumnContent: css`
    width: 100%;
  `,
  description: css`
    color: ${colors.dark40};
  `,
};
