import { css } from '@emotion/css';
import { baseFontFamily, colors } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
  `,
  counters: css`
    display: flex;
    flex: 1 0 auto;

    font-family: ${baseFontFamily};
    font-size: 14px;
    line-height: 22px;
    font-weight: 400;
  `,
  counter: css`
    flex: 0 0 auto;
    color: ${colors.dark};
    cursor: pointer;
    margin-right: 20px;
  `,
  counterInactive: css`
    color: ${colors.dark40};
  `,
  count: css`
    color: ${colors.dark40};
    padding-left: 5px;
  `,
  clusterFilter: css`
    flex: 0 0 385px;
    width: 385px;
    position: relative;
  `,
};
