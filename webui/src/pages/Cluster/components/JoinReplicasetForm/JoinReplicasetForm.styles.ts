import { css } from '@emotion/css';

export const styles = {
  wrap: css`
    width: calc(100% + 32px);
    margin-left: -16px;
    margin-right: -16px;
  `,
  filter: css`
    width: 305px;
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  wideField: css`
    flex-basis: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  radioWrap: css`
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  radio: css`
    flex-basis: calc(100% - 24px - 150px);
    max-width: calc(100% - 24px - 150px);
  `,
  replicasetServersCount: css`
    flex-basis: 120px;
    text-align: right;
    display: flex;
    align-items: center;
    justify-content: space-between;
  `,
  roles: css`
    flex-basis: 100%;
    margin-top: 8px;
  `,
  replicasetServersTooltip: css`
    padding: 0;
    margin: 8px 0;
    list-style: none;
  `,
  tooltipListItem: css`
    color: #ffffff;
    margin-bottom: 8px;

    &:last-child {
      margin-bottom: 0;
    }
  `,
  tooltipLeaderFlag: css`
    margin-left: 28px;
  `,
};
