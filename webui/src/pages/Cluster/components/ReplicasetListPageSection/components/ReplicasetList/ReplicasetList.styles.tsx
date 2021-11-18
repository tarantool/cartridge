import { css } from '@emotion/css';

export const styles = {
  header: css`
    position: relative;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 103px;
  `,
  alias: css`
    flex-basis: 458px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 16px;
    margin-bottom: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  statusGroup: css`
    display: flex;
    flex-basis: 592px;
    flex-shrink: 0;
    margin-right: -55px;
    margin-bottom: 12px;
  `,
  statusWrap: css`
    flex-shrink: 0;
    flex-basis: 193px;
  `,
  status: css`
    display: flex;
    align-items: center;
    height: 22px;
    margin-left: -8px;
    margin-right: 12px;
  `,
  statusWarning: css`
    color: rgba(245, 34, 45, 0.65);
  `,
  statusButton: css`
    display: block;
    padding-left: 8px;
    padding-right: 8px;
    margin-left: -8px;
    margin-top: -1px;
    margin-bottom: -1px;
  `,
  vshardTooltip: css`
    display: inline;
    font-weight: bold;
  `,
  vshard: css`
    position: absolute;
    right: 76px;
    width: 343px;
    margin-left: 12px;
    margin-right: 12px;
    color: rgba(0, 0, 0, 0.65);

    & > * {
      position: relative;
      margin-right: 17px;

      &::before {
        content: '';
        position: absolute;
        top: 0px;
        right: -8px;
        width: 1px;
        height: 18px;
        background-color: #e8e8e8;
      }
    }

    & > *:last-child {
      margin-right: 0;

      &::before {
        content: none;
      }
    }
  `,
  editBtn: css`
    position: absolute;
    top: 1px;
    right: 0;
    flex-shrink: 0;
  `,
  roles: css`
    margin-top: 0;
    margin-bottom: 12px;
  `,
  divider: css`
    height: 1px;
    margin-top: 16px;
    margin-bottom: 12px;
    background-color: #e8e8e8;
  `,
};
