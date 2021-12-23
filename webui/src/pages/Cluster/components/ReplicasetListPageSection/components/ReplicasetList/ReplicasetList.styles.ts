import { css } from '@emotion/css';

export const styles = {
  root: css`
    margin-top: 14px;
  `,
  row: css`
    padding: 0;
    overflow: hidden;
  `,
  replicaset: css`
    padding: 16px 20px 0 20px;
  `,
  header: css`
    position: relative;
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
  `,
  alias: css`
    flex: 0 1 auto;
    margin-bottom: 3px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  statusButton: css`
    padding-left: 8px;
    padding-right: 8px;
    margin-left: -8px;
    margin-top: -1px;
    margin-bottom: -1px;
    border-color: #d9dadd;
  `,
  tags: css`
    display: flex;
    flex-wrap: nowrap;

    flex: 0 0 190px;
    width: 190px;
    @media (max-width: 1200px) {
      flex: 0 0 180px;
      width: 180px;
    }
  `,
  status: css`
    flex: 0 0 140px;
    width: 140px;
  `,
  roles: css`
    margin: 0;
    margin-bottom: 5px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  editBtn: css`
    flex: 0 0 auto;
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
};
