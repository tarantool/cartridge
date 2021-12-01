import { css } from '@emotion/css';

export const styles = {
  serversList: css`
    padding: 16px;
    background: #ffffff;
    border: 1px solid #e8e8e8;
    margin: 0 0 24px;
    box-sizing: border-box;
    box-shadow: 0px 1px 10px rgba(0, 0, 0, 0.06);
    border-radius: 4px;
    list-style: none;

    & > * {
      margin-bottom: 4px;
    }

    & > *:last-child {
      margin-bottom: 0;
    }
  `,
  serversListItem: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
  `,
  serverListItemAlias: css`
    margin-right: 16px;
  `,
  serverListItemUri: css`
    display: flex;
    align-items: center;
  `,
};
