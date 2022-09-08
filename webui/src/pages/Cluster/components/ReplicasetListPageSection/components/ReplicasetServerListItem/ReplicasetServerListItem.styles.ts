import { css } from '@emotion/css';

export const styles = {
  root: css`
    position: relative;
    background-color: #fff;
    border-top: 1px solid #e6e7e8;
    height: 56px;
    padding: 0 20px;
  `,
  disabledRowWrap: css`
    background-color: #fafafa;
  `,
  filterIsNotMatching: css`
    opacity: 0.3;
  `,
  disabledRow: css`
    > *:not(.no-opacity) {
      opacity: 0.4;
    }
  `,
  row: css`
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
    height: 100%;
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
    left: 0;
    z-index: 1;
  `,
  nonElectableFlag: css`
    position: absolute;
    bottom: 0;
    left: 0;
    z-index: 0;
  `,
  head: css`
    flex: 0 0 auto;
    display: flex;
    flex-direction: row;
    @media (max-width: 1200px) {
      flex-direction: column;
    }
  `,
  aliasWrp: css`
    display: flex;
    align-items: center;

    flex: 0 0 240px;
    width: 240px;

    @media (max-width: 1200px) {
      flex-basis: auto;
      width: auto;
    }
  `,
  labelWrp: css`
    display: flex;
    align-items: center;

    flex: 0 1 auto;
  `,
  div: css`
    flex: 0 0 30px;
    width: 30px;
    @media (max-width: 1200px) {
      flex: 0 0 20px;
      width: 20px;
    }
  `,
  grow: css`
    flex-grow: 1 !important;
  `,
  sign: css`
    flex: 0 0 20px;
    width: 20px;
  `,
  signWithAlias: css`
    @media (max-width: 1200px) {
      padding-bottom: 16px;
    }
  `,
  alias: css`
    flex: 0 0 220px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    width: 220px;

    @media (max-width: 1200px) {
      flex-basis: auto;
      width: auto;
    }
  `,
  label: css`
    flex: 0 1 auto;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  `,
  mem: css`
    width: 90px;
  `,
  buckets: css`
    width: 70px;
  `,
  status: css`
    width: 140px;
  `,
  configureBtn: css`
    width: 32px;
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
    justify-content: center;
  `,
};
