import { css } from '@emotion/css';

export const styles = {
  uriIcon: css`
    margin-right: 4px;
  `,
  alias: css`
    flex-basis: 404px;
    max-width: 404px;
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  serverUriWrap: css`
    flex-basis: 445px;
    max-width: 445px;
    justify-content: flex-end;
    margin-left: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  leaderFlag: css`
    flex-shrink: 0;
    align-self: center;
    margin-left: 8px;
    margin-right: 8px;
  `,
  iconMargin: css`
    margin-right: 8px;
  `,
  sortableItem: css`
    position: relative;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;
    display: flex;
    flex-direction: row;
    cursor: move;

    &:last-child {
      border-bottom: none;
    }
  `,
  helper: css`
    z-index: 120;
  `,
  container: css`
    display: flex;
    flex-direction: column;
    width: 100%;
  `,
};
