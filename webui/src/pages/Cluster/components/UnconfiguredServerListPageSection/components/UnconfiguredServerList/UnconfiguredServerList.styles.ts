import { css } from '@emotion/css';

export const styles = {
  row: css`
    position: relative;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 159px;
    padding-bottom: 4px;
  `,
  checkBox: css`
    flex-shrink: 0;
    align-self: center;
    margin-right: 16px;
  `,
  heading: css`
    flex-basis: 458px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 16px;
    margin-bottom: 8px;
    overflow: hidden;
  `,
  status: css`
    display: flex;
    flex-basis: 505px;
    flex-shrink: 0;
    align-items: center;
    margin-bottom: 8px;
    margin-left: -8px;
  `,
  configureBtn: css`
    position: absolute;
    top: 12px;
    right: 16px;
  `,
  hiddenButton: css`
    visibility: hidden;
  `,
};
