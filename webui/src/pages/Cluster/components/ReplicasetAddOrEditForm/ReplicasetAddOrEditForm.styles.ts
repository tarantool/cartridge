import { css } from '@emotion/css';

export const styles = {
  wrap: css`
    display: flex;
    flex-wrap: wrap;
    width: calc(100% + 32px);
    margin-left: -16px;
    margin-right: -16px;
  `,
  weightInput: css`
    width: 97px;
  `,
  radioWrap: css`
    display: flex;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  field: css`
    flex-basis: calc(33.33% - 32px);
    margin-left: 16px;
    margin-right: 16px;
  `,
  wideField: css`
    flex-basis: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  doubleField: css`
    flex-basis: calc(66% - 32px);
    flex-grow: 1;
    margin-left: 16px;
    margin-right: 16px;
  `,
};
