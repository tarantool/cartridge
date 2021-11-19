import { css } from '@emotion/css';

export const styles = {
  replicaset: css`
    padding: 16px;
    background: #ffffff;
    border: 1px solid #e8e8e8;
    margin: 0 0 24px;
    box-sizing: border-box;
    box-shadow: 0px 1px 10px rgba(0, 0, 0, 0.06);
    border-radius: 4px;
  `,
  headingWrap: css`
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  `,
  alias: css`
    overflow: hidden;
    text-overflow: ellipsis;
  `,
  uuid: css`
    opacity: 0.65;
  `,
  status: css`
    flex-basis: 402px;
    margin-left: 24px;
  `,
};
