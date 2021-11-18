import { css } from '@emotion/css';

export const styles = {
  rowWrap: css`
    position: relative;
    padding-left: 32px;
  `,
  disabledRowWrap: css`
    background-color: #fafafa;
  `,
  row: css`
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 31px;
    margin-bottom: -8px;
  `,
  disabledRow: css`
    opacity: 0.4;
  `,
  heading: css`
    flex-basis: 415px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 16px;
    margin-bottom: 8px;
    overflow: hidden;
  `,
  alias: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  aliasLink: css`
    color: #000;

    &:hover,
    &:active {
      color: #000;
    }

    &:focus {
      color: #777;
    }
  `,
  leaderFlag: css`
    position: absolute;
    top: 0;
    left: 3px;
  `,
  iconMargin: css`
    margin-right: 4px;
  `,
  statusGroup: css`
    display: flex;
    flex-basis: 576px;
    flex-shrink: 0;
    flex-grow: 1;
    align-items: flex-start;
    margin-bottom: 8px;
  `,
  memStats: css`
    flex-shrink: 0;
    width: 246px;
  `,
  memStatsRow: css`
    display: flex;
    align-items: center;
  `,
  statsText: css`
    white-space: nowrap;
  `,
  memProgress: css`
    width: auto;
    margin-left: 20px;
  `,
  status: css`
    flex-basis: 193px;
    flex-shrink: 0;
    margin-top: 1px;
    margin-right: 16px;
    margin-left: -8px;
  `,
  stats: css`
    position: absolute;
    right: 46px;
    display: flex;
    flex-shrink: 0;
    align-items: stretch;
    margin-left: auto;
    width: 384px;
  `,
  bucketsCount: css`
    flex-shrink: 0;
    display: flex;
    align-items: center;
    width: 122px;
    margin-right: 16px;
  `,
  tags: css`
    margin-top: 8px;
  `,
  configureBtn: css`
    position: absolute;
    top: 12px;
    right: 12px;
  `,
};
