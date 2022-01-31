import { css } from '@emotion/css';

export const styles = {
  root: css``,
  row: css`
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
    margin-bottom: 10px;
    padding: 15px 20px;
  `,
  sign: css`
    flex: 0 0 20px;
  `,
  alias: css`
    flex: 0 0 220px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;

    @media (max-width: 1200px) {
      flex-basis: 170px;
    }
  `,
  label: css`
    flex: 0 1 auto;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  `,
  div: css`
    flex: 0 0 30px;
    @media (max-width: 1200px) {
      flex: 0 0 20px;
    }
  `,
  grow: css`
    flex-grow: 1 !important;
  `,
  actions: css``,
};
