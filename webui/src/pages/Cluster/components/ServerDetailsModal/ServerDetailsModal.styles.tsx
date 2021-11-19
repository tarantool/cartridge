import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  firstLine: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 21px;
  `,
  modal: css`
    max-width: 1050px;
  `,
  flag: css`
    margin-left: 20px;
    margin-bottom: 3px;
    vertical-align: middle;
  `,
  flagMarginBetween: css`
    margin-left: 10px;
  `,
  headingWidthLimit: css`
    max-width: 780px;
    display: inline-block;
    overflow: hidden;
    text-overflow: ellipsis;
    vertical-align: bottom;
  `,
  popover: css`
    padding: 8px 0;
  `,
  noZoneLabel: css`
    display: block;
    padding: 12px 18px 5px;
    color: ${colors.dark40};
    white-space: pre-wrap;
  `,
  zoneAddBtn: css`
    margin: 12px 20px;
  `,
  zone: css`
    position: relative;
    padding-left: 32px;
  `,
  activeZone: css`
    &:before {
      position: absolute;
      display: block;
      top: 50%;
      transform: translateY(-50%);
      content: '';
      height: 6px;
      width: 6px;
      border-radius: 50%;
      margin-left: -16px;
      background-color: ${colors.intentPrimary};
    }
  `,
};
