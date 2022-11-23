import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  inputs: css`
    display: flex;
    flex-wrap: wrap;
    margin-left: -16px;
    margin-right: -16px;
  `,
  inputField: css`
    flex-shrink: 0;
    width: calc(50% - 32px);
    margin-left: 16px;
    margin-right: 16px;
    box-sizing: border-box;
  `,
  infoTooltip: css`
    color: inherit;
    font-size: inherit;
    white-space: pre-line;
  `,
  fencingCheckboxMessage: css`
    display: block;
    min-height: 20px;
    margin-bottom: 10px;
  `,
  failoverInfo: css`
    color: ${colors.dark65};
    margin-top: 5px;
  `,
  failoverLabelDeprecated: css`
    color: ${colors.dark40};
  `,
  select: css`
    width: 100%;
  `,
};
