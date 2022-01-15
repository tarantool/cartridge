import { css } from '@emotion/css';
import { baseFontFamily, colors } from '@tarantool.io/ui-kit';

export const styles = {
  root: css`
    display: flex;
    align-items: center;
    flex-wrap: nowrap;
    overflow: hidden;
  `,
  label: css`
    font-family: ${baseFontFamily};
    font-weight: 600;
    font-size: 11px;
    line-height: 22px;

    letter-spacing: 0.01em;
    text-transform: uppercase;

    flex: 0 1 auto;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  `,
  icon: css`
    flex: 0 0 auto;
    margin-left: 5px;
    margin-bottom: 2px;
  `,
};

export const states = {
  bad: css`
    color: ${colors.intentDanger};
    svg {
      fill: ${colors.intentDanger};
    }
  `,
  good: css`
    color: ${colors.dark65};
    svg {
      fill: ${colors.dark65};
    }
  `,
  middle: css`
    color: ${colors.intentWarningAccent};
    svg {
      fill: ${colors.intentWarningAccent};
    }
  `,
};
